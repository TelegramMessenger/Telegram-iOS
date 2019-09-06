#!/bin/bash

if [ -z "$TELEGRAM_ENV_SET" ]; then
	echo "Error: Telegram build environment is not set up. Use sh public.sh make ${command}"
	exit 1
fi
