FROM rocker/shiny:4.1.2
RUN install2.r curl jsonlite \
    && rm -rf /tmp/downloaded_packages
COPY . /srv/shiny-server
USER shiny
