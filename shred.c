#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#define PASSES 3
#define COLOR_RED "\x1b[31m"
#define COLOR_RESET "\x1b[0m"

void shred_file(const char* filename) {
    struct stat st;
    if (stat(filename, &st) != 0) {
        perror("Error accessing file");
        return;
    }

    off_t size = st.st_size;
    int fd = open(filename, O_WRONLY);
    if (fd == -1) {
        perror("Error opening file for shredding");
        return;
    }

    printf(COLOR_RED "Shredding %s (%ld bytes)...\n" COLOR_RESET, filename, size);

    // Overwrite with multiple passes
    for (int p = 1; p <= PASSES; p++) {
        printf("Pass %d/%d (Random Data)...\n", p, PASSES);
        lseek(fd, 0, SEEK_SET);
        for (off_t i = 0; i < size; i++) {
            char random_byte = rand() % 256;
            write(fd, &random_byte, 1);
        }
        fsync(fd); // Force write to disk
    }

    close(fd);
    
    // Final removal
    if (unlink(filename) == 0) {
        printf("File securely removed.\n");
    } else {
        perror("Error removing file");
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: shredder <filename>\n");
        return 1;
    }

    shred_file(argv[1]);
    return 0;
}