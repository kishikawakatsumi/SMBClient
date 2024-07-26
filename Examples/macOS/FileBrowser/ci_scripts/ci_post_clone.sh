#!/bin/sh

if [ $CI_PRODUCT_PLATFORM = 'macOS' ]
then
  rm -rf "../../iOS"
else
  rm -rf "../../macOS"
fi
