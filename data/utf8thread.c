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

sem_t stdio_mutex;

#define PRINT(args...) do {sem_wait(&stdio_mutex);	\
	printf(args);					\
	fflush(stdout);					\
	sem_post(&stdio_mutex);				\
    } while(0)

/* #define DEBUG(args...)		PRINT(args) */
#define DEBUG(...)

#define DEFAULT_CHAR ' '
#define WORKERS 8
#define MESSAGE_DENSITY 1000000000

typedef unsigned long long u64;

#define UTF_LC(l) ((0xff >> (8 - (l))) << (8 - (l)))
#define UTF_CHECK(l, c) (((UTF_LC(l) & (c)) == UTF_LC(l)) && (0 == ((c) & (1 << (7-(l))))))


#define UTF_LEN(x) (UTF_CHECK(6, x) ? 6 :	\
		    UTF_CHECK(5, x) ? 5 :	\
		    UTF_CHECK(4, x) ? 4 :	\
		    UTF_CHECK(3, x) ? 3 :	\
		    UTF_CHECK(2, x) ? 2 : -1)

struct crange {
    u64 start, end;
};

/* Get return the next character after the last correct one. */
inline u64 valid_utf8(u64 c)
{
    char i;
    /* Ascii */
    if ((*(char*)c & 0x80) == 0)
	return c+1;

    /*  */
    for (i = UTF_LEN(*(char*)c)-1; i>0; i--) {
	c++;
	if (!UTF_CHECK(1, *(char*)c)) {
	    return (u64)NULL;
	}
    }

    return i<0 ? 0 : c+1;
}


void* fix_range(void* _r)
{
    struct crange* r = _r;
    u64 tmp, id = r->start;
    long long unsigned count = 0;

    while ((u64)r->start < (u64)r->end) {
	if (count++ % MESSAGE_DENSITY == 0)
	    printf ("[worker: 0x%016llx] Done with %lluK.\n", id, count % 1024);

	if (!(tmp = valid_utf8(r->start))){
	    PRINT("Invalid char 0x%x (next: 0x%x)\n",
		  *(char*)r->start, *(char*)(r->start+1));
	    *((char*)r->start) = DEFAULT_CHAR;
	    (r->start)++;
	} else {
	    r->start = tmp;
	}
    }

    PRINT ("[worker: 0x%016llx] OUT\n", id);
    return NULL;
}

void run(u64 p, u64 sz)
{
    int n, i;
    u64 wsize;
    pthread_t workers[WORKERS];
    struct crange rngs[WORKERS];

    wsize = sz/WORKERS + 1;
    printf("Base address: 0x%016llx, step size: 0x%016llx\n", p, wsize);

    for (i=0; i<WORKERS; i++){
	rngs[i].start = p + wsize*i;
	rngs[i].end = p + wsize*i + wsize;

	PRINT("Spawning worker %d on range [0x%016llx, 0x%016llx), %llu bytes...", i, rngs[i].start, rngs[i].end, wsize);
	if ((n = pthread_create(workers+i, NULL, fix_range, (void*)(rngs+i)))) {
	    PRINT("FAIL\n");
	    perror("worker");
	    return;
	}
	PRINT("OK\n");
    }

    PRINT ("Wrapping up...\n");
    for (i=0; i<WORKERS; i++) {
	PRINT ("Joining worker %d...", i);
	pthread_join(workers[i], NULL);
	PRINT ("OK\n");
	PRINT("Worker %d went through %llu bytes.\n",
	      i, (u64)rngs[i].end - (u64)rngs[i].start);
    }
}


int main(int argc, char *argv[])
{
    int fd;
    long long int sz, p;
    struct stat buf;

    sem_init(&stdio_mutex, 0 /* Shared. Usually ignored */ , 1);

    fd = open(argv[1], O_RDWR, 0x0666);
    if (fd == -1) {
	perror("open");
	return 1;
    }

    fstat(fd, &buf);
    sz = buf.st_size;
    printf("File size: 0x%016llx\n", sz);

    p = (u64)mmap (0, buf.st_size, PROT_READ | PROT_WRITE , MAP_SHARED, fd, 0);
    if (p == -1) {
	perror ("mmap");
	return 1;
    }

    run(p, buf.st_size);

    if (close (fd) == -1) {
	perror ("close");
	return 1;
    }


    if (munmap ((void*)p, buf.st_size) == -1) {
	perror ("munmap");
	return 1;
    }

    sem_destroy(&stdio_mutex);

    return 0;
}
