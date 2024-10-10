# Use an official Alpine Linux as a parent image
FROM alpine:latest

# Install necessary packages
RUN apk add --no-cache gcc make libc-dev

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY ./src .

# Compile the FTP server
RUN make all

# Expose the FTP port
EXPOSE 21

# Run the server
ENTRYPOINT ["./server"]