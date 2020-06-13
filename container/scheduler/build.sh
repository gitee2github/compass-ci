#!/bin/bash
. ../lab.sh

bash ../../scheduler/build.sh
mv ../../scheduler/m_scheduler ./scheduler

docker build -t sch-ruby-a:v0.00d-${SCHED_PORT:-3000} .

rm scheduler
