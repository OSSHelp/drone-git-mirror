FROM alpine:3.10.5
RUN apk add --no-cache bash=5.0.0-r0 git=2.22.4-r0 rsync=3.1.3-r1 openssh-client=8.1_p1-r0
COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["entrypoint.sh"]
