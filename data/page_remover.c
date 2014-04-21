/*
 * Copyright 2014 Chris Perivolaropoulos <cperivol@csail.mit.edu>
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details.  You should
 * have received a copy of the GNU General Public License along with
 * this program.
 *
 * If not, see <http://www.gnu.org/licenses/>.
 *
 * This should fill a range in a file with spaces. This is an in-place
 * operation so it should be pretty fast.
 *
 * Usage: page_remover PATH OFFSET LENGHT
 */

#include <assert.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <semaphore.h>
#include <unistd.h>
#include <unistd.h>

#define USAGE_INFO "page_remover PATH OFFSET LENGTH"
#define PRINT(ctx, args...) do { sem_wait(&ctx->stdio_mutex);	\
				 printf(args);			\
				 fflush(stdout);		\
				 sem_post(&ctx->stdio_mutex);	\
				 } while(0)

typedef struct context {
    int fd;
    size_t size;
    off_t off;
    sem_t stdio_mutex;
    void* data;
} context_t;

context_t* context_init(char* fname, off_t off, size_t len)
{
    context_t * ctx = (context_t*)malloc(sizeof(context_t));

    sem_init(&ctx->stdio_mutex, 0 /* Shared. Usually ignored */ , 1);

    PRINT(ctx, "Opening %s at %lu (len: %lu)\n", fname, off, len);

    ctx->off = off;
    ctx->fd = open(fname, O_RDWR, 0x0666);
    if (ctx->fd == -1) {
	perror("open");
	return NULL;
    }

    ctx->size = len;
    ctx->data = mmap(0, len, PROT_READ | PROT_WRITE,
		     MAP_SHARED, ctx->fd, 0);
    if (ctx->data == MAP_FAILED) {
	perror ("mmap");
	return NULL;
    }

    return ctx;
}

void context_destroy(context_t* ctx)
{
    if (close (ctx->fd) == -1)
	perror ("close");

    if (munmap ((void*)ctx->data, ctx->size) == -1)
	perror ("munmap");

    sem_destroy(&ctx->stdio_mutex);
    free(ctx);
}

int main(int argc, char *argv[])
{
    if (argc != 4)
	fprintf(stderr, USAGE_INFO);

    context_t *ctx = context_init(argv[1], atoi(argv[2]), atoi(argv[3]));

    /* You MIGHT want to thread this but I dont think it will make
     * much more difference than memset. */
    memset(ctx->data + ctx->off, ' ', ctx->size);

    context_destroy(ctx);
    return 0;
}
