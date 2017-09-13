
module zhang2018.common.Log;

import std.string;
import std.stdio;
import std.datetime;
import std.format;

private:
immutable string PRINT_COLOR_NONE  = "\033[m";
immutable string PRINT_COLOR_RED   =  "\033[0;32;31m";
immutable string PRINT_COLOR_GREEN  = "\033[0;32;32m";
immutable string PRINT_COLOR_YELLOW = "\033[1;33m";
//#define PRINT_COLOR_BLUE         "\033[0;32;34m"
//#define PRINT_COLOR_WHITE        "\033[1;37m"
//#define PRINT_COLOR_CYAN         "\033[0;36m"
//#define PRINT_COLOR_PURPLE       "\033[0;35m"
//#define PRINT_COLOR_BROWN        "\033[0;33m"
//#define PRINT_COLOR_DARY_GRAY    "\033[1;30m"
//#define PRINT_COLOR_LIGHT_RED    "\033[1;31m"
//#define PRINT_COLOR_LIGHT_GREEN  "\033[1;32m"
//#define PRINT_COLOR_LIGHT_BLUE   "\033[1;34m"
//#define PRINT_COLOR_LIGHT_CYAN   "\033[1;36m"
//#define PRINT_COLOR_LIGHT_PURPLE "\033[1;35m"
//#define PRINT_COLOR_LIGHT_GRAY   "\033[0;37m"


version(Windows)
{
	import core.sys.windows.wincon;
	import core.sys.windows.winbase;
	import core.sys.windows.windef;

	__gshared HANDLE g_hout = null;

	void win_writeln(string msg , ushort color)
	{
		if(g_hout is null)
			g_hout = GetStdHandle(STD_OUTPUT_HANDLE);
		SetConsoleTextAttribute(g_hout , color);
		writeln(msg);
		SetConsoleTextAttribute(g_hout ,  FOREGROUND_BLUE|FOREGROUND_GREEN|FOREGROUND_RED);
	}

}

enum KissLogLevel
{
	debug_ = 1,
	info = 2,
	warning = 3,
	error = 4,
	critical = 5,
	fatal = 6
}

/*
 * Convert level from string type to Level
 */
KissLogLevel toLevel(string str)
{
	KissLogLevel l = KissLogLevel.debug_;
	switch (str)
	{
		case "debug":
			l = KissLogLevel.debug_;
			break;
		case "info":
			l = KissLogLevel.info;
			break;
		case "warning":
			l = KissLogLevel.warning;
			break;
		case "error":
			l = KissLogLevel.error;
			break;
		case "critical":
			l = KissLogLevel.critical;
			break;
		case "fatal":
			l = KissLogLevel.fatal;
			break;	
		default:
			l = KissLogLevel.debug_;
			break;
	}
	return l;
}


string levelToString(KissLogLevel level)
{
	string l;
	final switch (level)
	{
		case KissLogLevel.debug_:
			l = "debug";
			break;
		case KissLogLevel.info:
			l = "info";
			break;
		case KissLogLevel.warning:
			l = "warning";
			break;
		case KissLogLevel.error:
			l = "error";
			break;
		case KissLogLevel.critical:
			l = "critical";
			break;
		case KissLogLevel.fatal:
			l = "fatal";
			break;			
	}
	return l;
}


//like printf("%s%d" , "test" , 1);
public string log_format(A ...)(A args)
{
	auto strings = appender!string();
	formattedWrite(strings, args);
	return strings.data;
}



//like writeln("test" , 1);
public string log_get(A ...)(A args)
{
	auto w = appender!string();
	foreach (arg; args)
	{
		alias A = typeof(arg);
		static if (isAggregateType!A || is(A == enum))
		{
			import std.format : formattedWrite;
			
			formattedWrite(w, "%s", arg);
		}
		else static if (isSomeString!A)
		{
			put(w, arg);
		}
		else static if (isIntegral!A)
		{
			import std.conv : toTextRange;
			
			toTextRange(arg, w);
		}
		else static if (isBoolean!A)
		{
			put(w, arg ? "true" : "false");
		}
		else static if (isSomeChar!A)
		{
			put(w, arg);
		}
		else
		{
			import std.format : formattedWrite;
			
			// Most general case
			formattedWrite(w, "%s", arg);
		}
	}
	return w.data;
}


private string convTostr(A ...)(string file , size_t line , A args)
{
	import std.conv;
	if(g_exe is null)
		return  log_get(args) ~ " - " ~ file ~ ":" ~ to!string(line);
	else
		return	g_exe ~ " - " ~log_get(args) ~ " - " ~ file ~ ":" ~ to!string(line);
}



void log_kiss(A ...)(KissLogLevel level ,  string file   , size_t line  , A args)
{

	string time_prior = format("%-27s", Clock.currTime.toISOExtString());
	version(Posix)
	{
		string prior;
		string suffix;
		if(level == KissLogLevel.error || 
			level == KissLogLevel.fatal || 
			level == KissLogLevel.critical)
		{
			prior = PRINT_COLOR_RED;
			suffix = PRINT_COLOR_NONE;
		}
		else if( level == KissLogLevel.info)
		{
			prior = PRINT_COLOR_GREEN;
			suffix = PRINT_COLOR_NONE;
		}
		else if(level == KissLogLevel.warning)
		{
			prior = PRINT_COLOR_YELLOW;
			suffix = PRINT_COLOR_NONE;
		}

		string msg = convTostr(file , line , args);
		msg = time_prior ~ " [" ~ levelToString(level)  ~ "] " ~ msg ;
		msg = prior ~ msg ~ suffix;
		writeln(msg);
	}
	else
	{
		string msg = convTostr(file , line , args);
		msg =   time_prior ~ " [" ~ levelToString(level)  ~ "] " ~ msg ;
		if(level == KissLogLevel.error || 
			level == KissLogLevel.fatal || 
			level == KissLogLevel.critical)
		{
			win_writeln(msg , FOREGROUND_RED);
		}
		else if( level == KissLogLevel.info)
		{
			win_writeln(msg , FOREGROUND_GREEN);
		}
		else if(level == KissLogLevel.warning)
		{
			win_writeln(msg , FOREGROUND_GREEN|FOREGROUND_RED );
		}
		else
		{
			writeln(msg);
		}
	}

}


version(onyxLog)
{
	import onyx.log;
	import onyx.bundle;
	import core.sys.windows.winbase;
	import std.array;
	import std.traits;
	import std.range;

	__gshared string 		g_exe;
	__gshared Log 			g_log;
	__gshared KissLogLevel 	g_level;

public:
	bool load_log_conf(immutable string logConfPath , string execute_tag = string.init)
	{
		if(g_log is null)
		{
			auto bundle = new immutable Bundle(logConfPath);
			createLoggers(bundle);
			g_exe = execute_tag;
			g_log = getLogger("logger");
			g_level = toLevel(g_log.level());
		}
		return true;
	}


	void log_debug(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{
		if(g_log !is null )
			g_log.debug_(convTostr(file , line , args));

		if( KissLogLevel.debug_ >= g_level)
			log_kiss(KissLogLevel.debug_ , file , line , args);
	}

	void log_info(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{
		if(g_log !is null)
			g_log.info(convTostr( file , line , args));

		if(KissLogLevel.info >= g_level)
			log_kiss(KissLogLevel.info , file , line , args);
	}

	void log_warning(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{
		if(g_log !is null)
			g_log.warning(convTostr( file , line , args));

		if(KissLogLevel.warning >= g_level)
			log_kiss(KissLogLevel.warning , file , line , args);
	}

	void log_error(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{
		if(g_log !is null)
			g_log.error(convTostr( file , line , args));

		if(KissLogLevel.error >= g_level)
			log_kiss( KissLogLevel.error , file , line , args);
	}

	void log_critical(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{
		if(g_log !is null)
			g_log.critical(convTostr( file , line , args));

		if(KissLogLevel.critical >= g_level)
			log_kiss(KissLogLevel.critical , file , line , args);
	}

	void log_fatal(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{
		if(g_log !is null)
			g_log.fatal(convTostr( file , line , args));

		if(KissLogLevel.fatal >= g_level)
			log_kiss(KissLogLevel.fatal , file , line , args);
	}

}
else
{
public:
	bool load_log_conf(immutable string logConfPath)
	{
		return true;
	}
	void log_debug(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{

		log_kiss(KissLogLevel.debug_ , file , line , args);
	}
	
	void log_info(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{

		log_kiss(KissLogLevel.info , file , line , args);
	}
	
	void log_warning(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{

		log_kiss(KissLogLevel.warning , file , line , args);
	}
	
	void log_error(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{

		log_kiss( KissLogLevel.error , file , line , args);
	}
	
	void log_critical(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{

		log_kiss(KissLogLevel.critical , file , line , args);
	}
	
	void log_fatal(string file = __FILE__ , size_t line = __LINE__ , A ...)(lazy A args)
	{
		log_kiss(KissLogLevel.fatal , file , line , args);
	}
}


