FROM alpine:latest as tpm2-build

RUN apk update && apk upgrade && \
  apk add --update alpine-sdk \
    curl-dev \
    openssl-dev && \
  rm -rf /var/cache/apk/*

WORKDIR /build
RUN wget https://downloads.sourceforge.net/project/ibmswtpm2/ibmtpm1661.tar.gz && \
    tar -xzf ibmtpm1661.tar.gz && \
    make -C src -j$(nproc)

COPY 001-tpm2-tss-select.patch .
RUN wget https://github.com/tpm2-software/tpm2-tss/releases/download/3.1.0/tpm2-tss-3.1.0.tar.gz && \
  tar -xzf tpm2-tss-3.1.0.tar.gz && \
  cd tpm2-tss-3.1.0 && \
  ./configure && \
  make -j$(nproc) && make install

RUN wget https://github.com/tpm2-software/tpm2-tools/releases/download/5.2/tpm2-tools-5.2.tar.gz && \
  tar -xzf tpm2-tools-5.2.tar.gz && \
  cd tpm2-tools-5.2 && \
  ./configure --disable-hardening --disable-unit --without-tcti-device --without-tcti-tabrmd && \
  make -j$(nproc) && make install

# The final image running only the simulator
FROM alpine:latest
LABEL description="TPM2 Simulator"

RUN apk update && apk upgrade && \ 
  apk add --update libssl1.1 && \
  rm -rf /var/cache/apk/*

WORKDIR /tpm2/
COPY --from=tpm2-build /build/src/tpm_server /bin
COPY --from=tpm2-build /usr/local/lib/libtcti-socket.so.0.0.0  /usr/local/lib/libsapi.so.0.0.0 /usr/local/lib/
RUN ln -s /usr/local/lib/libsapi.so.0.0.0 /usr/lib/libsapi.so && \
  ln -s /usr/local/lib/libsapi.so.0.0.0 /usr/lib/libsapi.so.0 && \
  ln -s /usr/local/lib/libtcti-socket.so.0.0.0 /usr/lib/libtcti-socket.so && \
  ln -s /usr/local/lib/libtcti-socket.so.0.0.0 /usr/lib/libtcti-socket.so.0 
COPY --from=tpm2-build /usr/local/bin/tpm* /usr/bin/

EXPOSE 2321
EXPOSE 2322

CMD [ "tpm_server" ]
