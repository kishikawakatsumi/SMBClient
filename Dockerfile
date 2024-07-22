FROM ghcr.io/servercontainers/samba

COPY --chmod=777 Tests/SMBClientTests/Fixtures /
