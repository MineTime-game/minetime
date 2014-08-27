/*
Minetest
Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#ifndef SETTINGS_HEADER
#define SETTINGS_HEADER

#include "irrlichttypes_bloated.h"
#include "exceptions.h"
#include <string>
#include "jthread/jmutex.h"
#include "jthread/jmutexautolock.h"
#include "strfnd.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include "debug.h"
#include "log.h"
#include "util/string.h"
#include "util/serialize.h"
#include <list>
#include <map>
#include <set>
#include "filesys.h"
#include <cctype>

enum ValueType
{
	VALUETYPE_STRING,
	VALUETYPE_FLAG // Doesn't take any arguments
};

struct ValueSpec
{
	ValueSpec(ValueType a_type, const char *a_help=NULL)
	{
		type = a_type;
		help = a_help;
	}
	ValueType type;
	const char *help;
};

class Settings
{
public:
	Settings()
	{
	}

	void writeLines(std::ostream &os)
	{
		JMutexAutoLock lock(m_mutex);

		for(std::map<std::string, std::string>::iterator
				i = m_settings.begin();
				i != m_settings.end(); ++i)
		{
			std::string name = i->first;
			std::string value = i->second;
			os<<name<<" = "<<value<<"\n";
		}
	}
  
	// return all keys used
	std::vector<std::string> getNames(){
		std::vector<std::string> names;
		for(std::map<std::string, std::string>::iterator
				i = m_settings.begin();
				i != m_settings.end(); ++i)
		{
			names.push_back(i->first);
		}
		return names;
	}

	// remove a setting
	bool remove(const std::string& name)
	{
		return m_settings.erase(name);
	}


	bool parseConfigLine(const std::string &line)
	{
		JMutexAutoLock lock(m_mutex);

		std::string trimmedline = trim(line);

		// Ignore empty lines and comments
		if(trimmedline.size() == 0 || trimmedline[0] == '#')
			return true;

		//infostream<<"trimmedline=\""<<trimmedline<<"\""<<std::endl;

		Strfnd sf(trim(line));

		std::string name = sf.next("=");
		name = trim(name);

		if(name == "")
			return true;

		std::string value = sf.next("\n");
		value = trim(value);

		/*infostream<<"Config name=\""<<name<<"\" value=\""
				<<value<<"\""<<std::endl;*/

		m_settings[name] = value;

		return true;
	}

	void parseConfigLines(std::istream &is, const std::string &endstring)
	{
		for(;;){
			if(is.eof())
				break;
			std::string line;
			std::getline(is, line);
			std::string trimmedline = trim(line);
			if(endstring != ""){
				if(trimmedline == endstring)
					break;
			}
			parseConfigLine(line);
		}
	}

	// Returns false on EOF
	bool parseConfigObject(std::istream &is)
	{
		if(is.eof())
			return false;

		/*
			NOTE: This function might be expanded to allow multi-line
			      settings.
		*/
		std::string line;
		std::getline(is, line);
		//infostream<<"got line: \""<<line<<"\""<<std::endl;

		return parseConfigLine(line);
	}

	/*
		Read configuration file

		Returns true on success
	*/
	bool readConfigFile(const char *filename)
	{
		std::ifstream is(filename);
		if(is.good() == false)
			return false;

		/*infostream<<"Parsing configuration file: \""
				<<filename<<"\""<<std::endl;*/

		while(parseConfigObject(is));

		return true;
	}

	/*
		Reads a configuration object from stream (usually a single line)
		and adds it to dst.

		Preserves comments and empty lines.

		Settings that were added to dst are also added to updated.
		key of updated is setting name, value of updated is dummy.

		Returns false on EOF
	*/
	bool getUpdatedConfigObject(std::istream &is,
			std::list<std::string> &dst,
			std::set<std::string> &updated,
			bool &value_changed)
	{
		JMutexAutoLock lock(m_mutex);

		if(is.eof())
			return false;

		// NOTE: This function will be expanded to allow multi-line settings
		std::string line;
		std::getline(is, line);

		std::string trimmedline = trim(line);

		std::string line_end = "";
		if(is.eof() == false)
			line_end = "\n";

		// Ignore empty lines and comments
		if(trimmedline.size() == 0 || trimmedline[0] == '#')
		{
			dst.push_back(line+line_end);
			return true;
		}

		Strfnd sf(trim(line));

		std::string name = sf.next("=");
		name = trim(name);

		if(name == "")
		{
			dst.push_back(line+line_end);
			return true;
		}

		std::string value = sf.next("\n");
		value = trim(value);

		if(m_settings.find(name) != m_settings.end())
		{
			std::string newvalue = m_settings[name];

			if(newvalue != value)
			{
				infostream<<"Changing value of \""<<name<<"\" = \""
						<<value<<"\" -> \""<<newvalue<<"\""
						<<std::endl;
				value_changed = true;
			}

			dst.push_back(name + " = " + newvalue + line_end);

			updated.insert(name);
		}
		else //file contains a setting which is not in m_settings
			value_changed=true;
			
		return true;
	}

	/*
		Updates configuration file

		Returns true on success
	*/
	bool updateConfigFile(const char *filename)
	{
		infostream<<"Updating configuration file: \""
				<<filename<<"\""<<std::endl;

		std::list<std::string> objects;
		std::set<std::string> updated;
		bool something_actually_changed = false;

		// Read and modify stuff
		{
			std::ifstream is(filename);
			if(is.good() == false)
			{
				infostream<<"updateConfigFile():"
						" Error opening configuration file"
						" for reading: \""
						<<filename<<"\""<<std::endl;
			}
			else
			{
				while(getUpdatedConfigObject(is, objects, updated,
						something_actually_changed));
			}
		}

		JMutexAutoLock lock(m_mutex);

		// If something not yet determined to have been changed, check if
		// any new stuff was added
		if(!something_actually_changed){
			for(std::map<std::string, std::string>::iterator
					i = m_settings.begin();
					i != m_settings.end(); ++i)
			{
				if(updated.find(i->first) != updated.end())
					continue;
				something_actually_changed = true;
				break;
			}
		}

		// If nothing was actually changed, skip writing the file
		if(!something_actually_changed){
			infostream<<"Skipping writing of "<<filename
					<<" because content wouldn't be modified"<<std::endl;
			return true;
		}

		// Write stuff back
		{
			std::ostringstream ss(std::ios_base::binary);

			/*
				Write updated stuff
			*/
			for(std::list<std::string>::iterator
					i = objects.begin();
					i != objects.end(); ++i)
			{
				ss<<(*i);
			}

			/*
				Write stuff that was not already in the file
			*/
			for(std::map<std::string, std::string>::iterator
					i = m_settings.begin();
					i != m_settings.end(); ++i)
			{
				if(updated.find(i->first) != updated.end())
					continue;
				std::string name = i->first;
				std::string value = i->second;
				infostream<<"Adding \""<<name<<"\" = \""<<value<<"\""
						<<std::endl;
				ss<<name<<" = "<<value<<"\n";
			}

			if(!fs::safeWriteToFile(filename, ss.str()))
			{
				errorstream<<"Error writing configuration file: \""
						<<filename<<"\""<<std::endl;
				return false;
			}
		}

		return true;
	}

	/*
		NOTE: Types of allowed_options are ignored

		returns true on success
	*/
	bool parseCommandLine(int argc, char *argv[],
			std::map<std::string, ValueSpec> &allowed_options)
	{
		int nonopt_index = 0;
		int i=1;
		for(;;)
		{
			if(i >= argc)
				break;
			std::string argname = argv[i];
			if(argname.substr(0, 2) != "--")
			{
				// If option doesn't start with -, read it in as nonoptX
				if(argname[0] != '-'){
					std::string name = "nonopt";
					name += itos(nonopt_index);
					set(name, argname);
					nonopt_index++;
					i++;
					continue;
				}
				errorstream<<"Invalid command-line parameter \""
						<<argname<<"\": --<option> expected."<<std::endl;
				return false;
			}
			i++;

			std::string name = argname.substr(2);

			std::map<std::string, ValueSpec>::iterator n;
			n = allowed_options.find(name);
			if(n == allowed_options.end())
			{
				errorstream<<"Unknown command-line parameter \""
						<<argname<<"\""<<std::endl;
				return false;
			}

			ValueType type = n->second.type;

			std::string value = "";

			if(type == VALUETYPE_FLAG)
			{
				value = "true";
			}
			else
			{
				if(i >= argc)
				{
					errorstream<<"Invalid command-line parameter \""
							<<name<<"\": missing value"<<std::endl;
					return false;
				}
				value = argv[i];
				i++;
			}


			infostream<<"Valid command-line parameter: \""
					<<name<<"\" = \""<<value<<"\""
					<<std::endl;
			set(name, value);
		}

		return true;
	}

	void set(std::string name, std::string value)
	{
		JMutexAutoLock lock(m_mutex);

		m_settings[name] = value;
	}

	void set(std::string name, const char *value)
	{
		JMutexAutoLock lock(m_mutex);

		m_settings[name] = value;
	}


	void setDefault(std::string name, std::string value)
	{
		JMutexAutoLock lock(m_mutex);

		m_defaults[name] = value;
	}

	bool exists(std::string name)
	{
		JMutexAutoLock lock(m_mutex);

		return (m_settings.find(name) != m_settings.end() || m_defaults.find(name) != m_defaults.end());
	}

	std::string get(std::string name)
	{
		JMutexAutoLock lock(m_mutex);

		std::map<std::string, std::string>::iterator n;
		n = m_settings.find(name);
		if(n == m_settings.end())
		{
			n = m_defaults.find(name);
			if(n == m_defaults.end())
			{
				throw SettingNotFoundException(("Setting [" + name + "] not found ").c_str());
			}
		}

		return n->second;
	}

	//////////// Get setting
	bool getBool(std::string name)
	{
		return is_yes(get(name));
	}

	bool getFlag(std::string name)
	{
		try
		{
			return getBool(name);
		}
		catch(SettingNotFoundException &e)
		{
			return false;
		}
	}

	// Asks if empty
	bool getBoolAsk(std::string name, std::string question, bool def)
	{
		// If it is in settings
		if(exists(name))
			return getBool(name);

		std::string s;
		char templine[10];
		std::cout<<question<<" [y/N]: ";
		std::cin.getline(templine, 10);
		s = templine;

		if(s == "")
			return def;

		return is_yes(s);
	}

	float getFloat(std::string name)
	{
		return stof(get(name));
	}

	u16 getU16(std::string name)
	{
		return stoi(get(name), 0, 65535);
	}

	u16 getU16Ask(std::string name, std::string question, u16 def)
	{
		// If it is in settings
		if(exists(name))
			return getU16(name);

		std::string s;
		char templine[10];
		std::cout<<question<<" ["<<def<<"]: ";
		std::cin.getline(templine, 10);
		s = templine;

		if(s == "")
			return def;

		return stoi(s, 0, 65535);
	}

	s16 getS16(std::string name)
	{
		return stoi(get(name), -32768, 32767);
	}

	s32 getS32(std::string name)
	{
		return stoi(get(name));
	}

	v3f getV3F(std::string name)
	{
		v3f value;
		Strfnd f(get(name));
		f.next("(");
		value.X = stof(f.next(","));
		value.Y = stof(f.next(","));
		value.Z = stof(f.next(")"));
		return value;
	}

	v2f getV2F(std::string name)
	{
		v2f value;
		Strfnd f(get(name));
		f.next("(");
		value.X = stof(f.next(","));
		value.Y = stof(f.next(")"));
		return value;
	}

	u64 getU64(std::string name)
	{
		u64 value = 0;
		std::string s = get(name);
		std::istringstream ss(s);
		ss>>value;
		return value;
	}

	u32 getFlagStr(std::string name, FlagDesc *flagdesc, u32 *flagmask)
	{
		std::string val = get(name);
		return (std::isdigit(val[0])) ? stoi(val) :
			readFlagString(val, flagdesc, flagmask);
	}

	// N.B. if getStruct() is used to read a non-POD aggregate type,
	// the behavior is undefined.
	bool getStruct(std::string name, std::string format, void *out, size_t olen)
	{
		std::string valstr;

		try {
			valstr = get(name);
		} catch (SettingNotFoundException &e) {
			return false;
		}

		if (!deSerializeStringToStruct(valstr, format, out, olen))
			return false;

		return true;
	}

	//////////// Try to get value, no exception thrown
	bool getNoEx(std::string name, std::string &val)
	{
		try {
			val = get(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	// N.B. getFlagStrNoEx() does not set val, but merely modifies it.  Thus,
	// val must be initialized before using getFlagStrNoEx().  The intention of
	// this is to simplify modifying a flags field from a default value.
	bool getFlagStrNoEx(std::string name, u32 &val, FlagDesc *flagdesc)
	{
		try {
			u32 flags, flagmask;

			flags = getFlagStr(name, flagdesc, &flagmask);

			val &= ~flagmask;
			val |=  flags;

			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getFloatNoEx(std::string name, float &val)
	{
		try {
			val = getFloat(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getU16NoEx(std::string name, int &val)
	{
		try {
			val = getU16(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getU16NoEx(std::string name, u16 &val)
	{
		try {
			val = getU16(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getS16NoEx(std::string name, int &val)
	{
		try {
			val = getU16(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getS16NoEx(std::string name, s16 &val)
	{
		try {
			val = getS16(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getS32NoEx(std::string name, s32 &val)
	{
		try {
			val = getS32(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getV3FNoEx(std::string name, v3f &val)
	{
		try {
			val = getV3F(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getV2FNoEx(std::string name, v2f &val)
	{
		try {
			val = getV2F(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	bool getU64NoEx(std::string name, u64 &val)
	{
		try {
			val = getU64(name);
			return true;
		} catch (SettingNotFoundException &e) {
			return false;
		}
	}

	//////////// Set setting

	// N.B. if setStruct() is used to write a non-POD aggregate type,
	// the behavior is undefined.
	bool setStruct(std::string name, std::string format, void *value)
	{
		std::string structstr;
		if (!serializeStructToString(&structstr, format, value))
			return false;

		set(name, structstr);
		return true;
	}

	void setFlagStr(std::string name, u32 flags,
		FlagDesc *flagdesc, u32 flagmask)
	{
		set(name, writeFlagString(flags, flagdesc, flagmask));
	}

	void setBool(std::string name, bool value)
	{
		if(value)
			set(name, "true");
		else
			set(name, "false");
	}

	void setFloat(std::string name, float value)
	{
		set(name, ftos(value));
	}

	void setV3F(std::string name, v3f value)
	{
		std::ostringstream os;
		os<<"("<<value.X<<","<<value.Y<<","<<value.Z<<")";
		set(name, os.str());
	}

	void setV2F(std::string name, v2f value)
	{
		std::ostringstream os;
		os<<"("<<value.X<<","<<value.Y<<")";
		set(name, os.str());
	}

	void setS16(std::string name, s16 value)
	{
		set(name, itos(value));
	}

	void setS32(std::string name, s32 value)
	{
		set(name, itos(value));
	}

	void setU64(std::string name, u64 value)
	{
		std::ostringstream os;
		os<<value;
		set(name, os.str());
	}

	void clear()
	{
		JMutexAutoLock lock(m_mutex);

		m_settings.clear();
		m_defaults.clear();
	}

	void updateValue(Settings &other, const std::string &name)
	{
		JMutexAutoLock lock(m_mutex);

		if(&other == this)
			return;

		try{
			std::string val = other.get(name);
			m_settings[name] = val;
		} catch(SettingNotFoundException &e){
		}

		return;
	}

	void update(Settings &other)
	{
		JMutexAutoLock lock(m_mutex);
		JMutexAutoLock lock2(other.m_mutex);

		if(&other == this)
			return;

		m_settings.insert(other.m_settings.begin(), other.m_settings.end());
		m_defaults.insert(other.m_defaults.begin(), other.m_defaults.end());

		return;
	}

	Settings & operator+=(Settings &other)
	{
		JMutexAutoLock lock(m_mutex);
		JMutexAutoLock lock2(other.m_mutex);

		if(&other == this)
			return *this;

		update(other);

		return *this;

	}

	Settings & operator=(Settings &other)
	{
		JMutexAutoLock lock(m_mutex);
		JMutexAutoLock lock2(other.m_mutex);

		if(&other == this)
			return *this;

		clear();
		(*this) += other;

		return *this;
	}

private:
	std::map<std::string, std::string> m_settings;
	std::map<std::string, std::string> m_defaults;
	// All methods that access m_settings/m_defaults directly should lock this.
	JMutex m_mutex;
};

#endif

