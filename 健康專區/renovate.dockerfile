FROM renovate/renovate:latest

USER root

COPY FG4H1FT922900257.cer /usr/local/share/ca-certificates/
COPY FG201ETK19903375.cer /usr/local/share/ca-certificates/
COPY FG4H1FT922900257.crt /usr/local/share/ca-certificates/
COPY FG4H1FT922900264.cer /usr/local/share/ca-certificates/
COPY FG4H1FT922900264.crt /usr/local/share/ca-certificates/
COPY gitlab.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

USER 1000
