FROM rocker/shiny:4.1.2
COPY . /srv/shiny-server
RUN install2.r curl jsonlite \
    && rm -rf /tmp/downloaded_packages
USER shiny
