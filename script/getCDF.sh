#!/bin/bash

cd ./script
sudo erl -pa script -name stat@localhost -setcookie antidote -noshell -run getCDF get_cdf $1 -run init stop
cd -
