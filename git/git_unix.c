// $Id: git_unix.c,v 1.5 2004/01/25 18:44:51 iain Exp $

// unixstrt.c: Unix-specific code for Glulxe.
// Designed by Andrew Plotkin <erkyrath@eblong.com>
// http://www.eblong.com/zarf/glulx/index.html

#include "git.h"
#include "glk.h"
#include "glkstart.h" // This comes with the Glk library.

#if FROTZ_IOS
#include "iosfrotz.h"
#endif

#include <string.h>

#ifdef USE_MMAP
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <errno.h>
#endif

// The only command-line argument is the filename.
glkunix_argumentlist_t glkunix_arguments[] =
{
    { "", glkunix_arg_ValueFollows, "filename: The game file to load." },
    { NULL, glkunix_arg_End, NULL }
};

#define CACHE_SIZE (256 * 1024L)
#define UNDO_SIZE (2 * 1024 * 1024L)

void fatalError (const char * s)
{
#if FROTZ_IOS
    iosif_puts("*** fatal error: ");
    iosif_puts((char*)s);
    iosif_puts(" ***\n");
    finished = 1;
#endif
}

#ifdef USE_MMAP
// Fast loader that uses some fancy Unix features.

const char * gFilename = 0;
char * gStartupError = 0;

int glkunix_startup_code(glkunix_startup_t *data)
{
    if (data->argc <= 1)
    {
        gStartupError = "No file given";
        return 1;
    }
    gFilename = data->argv[1];
    return 1;
}

void glk_main ()
{
    int         file;
    struct stat info;
    git_uint8 * ptr;

	if (gStartupError)
		fatalError(gStartupError);

    file = open (gFilename, O_RDONLY);
    if (file < 0)
        goto error;

    if (fstat (file, &info) != 0)
        goto error;
    
    if (info.st_size < 256)
		fatalError("This is too small to be a glulx file.");

    ptr = mmap (NULL, info.st_size, PROT_READ, MAP_PRIVATE, file, 0);
    if (ptr == MAP_FAILED)
        goto error;
        
    git (ptr, info.st_size, CACHE_SIZE, UNDO_SIZE);
    munmap ((void*) ptr, info.st_size);
    return;
    
error:
    perror ("git");
    exit (errno);
}

#else
// Generic loader that should work anywhere.

strid_t gStream = 0;
char * gStartupError = 0;

int glkunix_startup_code(glkunix_startup_t *data)
{
    if (data->argc <= 1)
    {
        printf ("usage: git gamefile.ulx\n");
        return 0;
    }
    gStream = glkunix_stream_open_pathname ((char*) data->argv[1], 0, 0);
    return 1;
}

void glk_main ()
{
	if (gStartupError)
		fatalError(gStartupError);

    if (gStream == NULL)
        fatalError ("could not open game file");

    gitWithStream (gStream, CACHE_SIZE, UNDO_SIZE);

#if FROTZ_IOS
    git_shutdown_dispatch();
#endif

    gStream = NULL;
}

#endif // USE_MMAP
