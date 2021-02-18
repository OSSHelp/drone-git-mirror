FROM alpine:3.13
RUN apk add --no-cache bash=5.1.0-r0 git=2.30.1-r0 rsync=3.2.3-r1 openssh-client=8.4_p1-r2
COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["entrypoint.sh"]
