#include <stdlib.h>	// User for malloc() and free()
#include <stdio.h>	// Used for printf() and scanf()

int main( int argc, char** argv ) {
	const int length = 10000000;
	// Create two large arrays
	int* a = (int*) malloc( sizeof(int) * length );
	int* b = (int*) malloc( sizeof(int) * length );
	int* c = (int*) malloc( sizeof(int) * length );

	// Do some arbitrarily hard amount of work.
	for( int i = 0; i < length; i++ ) {
		c[i] = a[i] * b[i];
	}

	free(a);
	free(b);
	free(c);


	return 1;
}
