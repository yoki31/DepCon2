#From alpine:3.9
From kubesigs/kube-batch

ADD kube-batch /usr/local/bin

RUN apk --no-cache add ca-certificates wget && wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk && apk add glibc-2.28-r0.apk

#ENTRYPOINT ["/usr/local/bin/kube-batch >> a.txt"]
