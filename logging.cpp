//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//


#include <stdio.h>
#include <stdarg.h>
#include <time.h>

FILE* tgvoipLogFile=NULL;

void tgvoip_log_file_printf(char level, const char* msg, ...){
	if(tgvoipLogFile){
		va_list argptr;
		va_start(argptr, msg);
		time_t t = time(0);
		struct tm *now = localtime(&t);
		fprintf(tgvoipLogFile, "%02d-%02d %02d:%02d:%02d %c: ", now->tm_mon + 1, now->tm_mday, now->tm_hour, now->tm_min, now->tm_sec, level);
		vfprintf(tgvoipLogFile, msg, argptr);
		fprintf(tgvoipLogFile, "\n");
		fflush(tgvoipLogFile);
	}
}
