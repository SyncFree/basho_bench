FROM erlang:19

WORKDIR /usr/src/basho_bench

COPY ./include /usr/src/basho_bench/include
COPY ./priv /usr/src/basho_bench/priv
COPY ./script /usr/src/basho_bench/script
COPY ./src /usr/src/basho_bench/src
COPY ./Makefile ./rebar.config ./rebar3 /usr/src/basho_bench/

RUN make

FROM erlang:19

RUN apt-get update && \
    apt-get install -y r-base

RUN echo "install.packages(\"plyr\", repos=\"http://cran.rstudio.com\")" | R --no-save && \
    echo "install.packages(\"grid\", repos=\"http://cran.rstudio.com\")" | R --no-save && \
    echo "install.packages(\"getopt\", repos=\"http://cran.rstudio.com\")" | R --no-save && \
    echo "install.packages(\"proto\", repos=\"http://cran.rstudio.com\")" | R --no-save && \
    echo "install.packages(\"ggplot2\", repos=\"http://cran.rstudio.com\")" | R --no-save
WORKDIR /opt/basho_bench
COPY --from=0 /usr/src/basho_bench/_build/default/bin/basho_bench .
COPY ./examples /opt/basho_bench/examples
COPY ./priv /opt/basho_bench/priv
COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
