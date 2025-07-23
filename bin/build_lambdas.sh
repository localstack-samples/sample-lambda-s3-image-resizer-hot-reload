#!/bin/bash

(cd lambdas/presign; rm -f lambda.zip; zip lambda.zip handler.py)

(cd lambdas/list; rm -f lambda.zip; zip lambda.zip handler.py)

os=$(uname -s)
if [ "$os" == "Darwin" ]; then
    (
        cd lambdas/resize
        rm -rf libs lambda.zip
        docker run --platform linux/x86_64 --rm -v "$PWD":/var/task "public.ecr.aws/sam/build-python3.11" /bin/sh -c "pip3 install -r requirements.txt -t libs; exit"

        cd libs && zip -r ../lambda.zip . && cd ..
        zip lambda.zip handler.py
        rm -rf libs
    )
else
    (
        cd lambdas/resize
        rm -rf package lambda.zip
        mkdir package
        pip3 install -r requirements.txt --platform manylinux2014_x86_64 --only-binary=:all: -t package
        zip lambda.zip handler.py
        cd package
        zip -r ../lambda.zip *;
    )
fi