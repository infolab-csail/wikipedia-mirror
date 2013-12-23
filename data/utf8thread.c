#include <assert.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <unistd.h>

#define DEFAULT_CHAR ' '
#define WORKERS 8

typedef unsigned long long u64;

#define UTF_LEN(x) (((x) & 0xfc) == 0xfc ? 6 :		\
		    ((x) & 0xf8) == 0xf8 ? 5 :		\
		    ((x) & 0xf0) == 0xf0 ? 4 :		\
		    ((x) & 0xe0) == 0xe0 ? 3 :		\
		    ((x) & 0xc0) == 0xc0 ? 2 :		\
		    ((x) & 0x80) == 0x80 ? 1 :		\
		    0)


struct crange {
    u64 start, end;
};


inline u64 valid_utf8(u64 c)
{
    char i;
    for (i=UTF_LEN(*(char*)c); i>0; i--) {
	c++;
	if (i != UTF_LEN(*(char*)c))
	    return (u64)NULL;
    }

    return c;
}


void* fix_range(void* _r)
{
    struct crange* r = _r;
    u64 tmp;
    unsigned count = 0;

    while ((u64)r->start < (u64)r->end) {
	count++;
	if (!(tmp = valid_utf8(r->start))){
	    *((char*)r->start) = DEFAULT_CHAR;
	    r->start++;
	} else
	    r->start = tmp;
    }

    return NULL;
}

void access_test(u64 p, u64 sz)
{
    u64 i;
    char tmp;
    for (i=0; i<sz; i++)
	tmp = *(char*)(p+i);
}

void run(u64 p, u64 sz)
{
    int n, i;
    u64 wsize;
    pthread_t workers[WORKERS];
    struct crange rngs[WORKERS];

    /* access_test(p,sz); */

    wsize = sz/WORKERS + 1;
    printf("Base address: 0x%016llx, step size: 0x%016llx\n", p, wsize);

    for (i=0; i<WORKERS; i++){
	rngs[i].start = p + wsize*i;
	rngs[i].end = p + wsize*i + wsize;

	printf("Spawning worker %d on range [0x%016llx, 0x%016llx)\n", i, rngs[i].start, rngs[i].end);
	if ((n = pthread_create(workers+i, NULL, fix_range, (void*)(rngs+i)))) {
	    perror("worker");
	    return;
	}
    }
    for (i=0; i<WORKERS; i++) {
	pthread_join(workers[i], NULL);
	printf("Worker %d went through %lld bytes.\n", i, (u64)rngs[i].end - (u64)rngs[i].start);
    }
}


int main(int argc, char *argv[])
{
    int fd;
    long long int sz, p;
    struct stat buf;

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

    return 0;
}
