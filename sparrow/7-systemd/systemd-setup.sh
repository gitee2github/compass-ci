#!/bin/bash

cp $(dirname $0)/cci-network.service /etc/systemd/system
systemctl daemon-reload
systemctl enable cci-network.service
systemctl start  cci-network.service
