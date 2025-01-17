/* buffer.c - Text buffering and word wrapping
 *	Copyright (c) 1995-1997 Stefan Jokisch
 *
 * This file is part of Frotz.
 *
 * Frotz is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Frotz is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#include "frotz.h"
#include <string.h>

extern void stream_char (unsigned int);
extern void stream_word (const zchar *);
extern void stream_new_line (void);

static zchar buffer[TEXT_BUFFER_SIZE];
static int bufpos = 0;

static zchar prev_c = 0;

/*
 * flush_buffer
 *
 * Copy the contents of the text buffer to the output streams.
 *
 */

void flush_buffer (void)
{
    static bool locked = FALSE;

    /* Make sure we stop when flush_buffer is called from flush_buffer.
       Note that this is difficult to avoid as we might print a newline
       during flush_buffer, which might cause a newline interrupt, that
       might execute any arbitrary opcode, which might flush the buffer. */

    if (locked || bufpos == 0)
	return;

    /* Send the buffer to the output streams */

    buffer[bufpos] = 0;


    locked = TRUE;

    stream_word (buffer); 

#ifdef SPEECH_OUTPUT
    os_speech_output(buffer);
#endif

    locked = FALSE;

    /* Reset the buffer */

    bufpos = 0;
    prev_c = 0;

}/* flush_buffer */

/*
 * print_char
 *
 * High level output function.
 *
 */

void print_char (unsigned int c)
{
    static bool flag = FALSE;
#if !USE_UTF8 // else use output-only hack that allows unicode table output only
    if (c >= 0x100)
        flush_buffer();
#endif
    if (message || ostream_memory || enable_buffering) {
        
        if (!flag) {
            
            /* Characters 0 and ZC_RETURN are special cases */
            
            if (c == ZC_RETURN)
            { new_line (); return; }
            if (c == 0)
                return;
            
            /* Flush the buffer before a whitespace or after a hyphen */
            
            if (c == ' ' || c == ZC_INDENT || c == ZC_GAP || (prev_c == '-' && c != '-'))
                
                
                flush_buffer ();
            
            /* Set the flag if this is part one of a style or font change */
            
            if (c == ZC_NEW_FONT || c == ZC_NEW_STYLE)
                flag = TRUE;
            
            /* Remember the current character code */
            
            prev_c = c;
            
        } else flag = FALSE;
        
        /* Insert the character into the buffer */
        
#if !USE_UTF8
        if (c >= 0x100)
            stream_char(c);
        else
#endif
        {
            buffer[bufpos++] = c;
            
            if (bufpos == TEXT_BUFFER_SIZE)
                runtime_error (ERR_TEXT_BUF_OVF);
        }
    } else stream_char (c);

}/* print_char */

/*
 * new_line
 *
 * High level newline function.
 *
 */

void new_line (void)
{

    flush_buffer (); stream_new_line ();

}/* new_line */


/*
 * init_buffer
 *
 * Initialize buffer variables.
 *
 */

void init_buffer(void)
{
    memset((void*)buffer, 0, sizeof (zchar) * TEXT_BUFFER_SIZE);
    bufpos = 0;
    prev_c = 0;
}

