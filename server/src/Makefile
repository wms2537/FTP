CC = gcc
CFLAGS = -Wall -Wextra -O2
TARGET = server

all: $(TARGET)

$(TARGET): ftp_server.o
	$(CC) $(CFLAGS) -o $(TARGET) ftp_server.o

ftp_server.o: ftp_server.c ftp_server.h
	$(CC) $(CFLAGS) -c ftp_server.c

clean:
	rm -f *.o $(TARGET)