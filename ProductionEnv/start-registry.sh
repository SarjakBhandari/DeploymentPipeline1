#!/bin/bash

# Run Docker Registry container
docker run -d \
  --restart=always \
  --name registry \
  -p 5000:5000 \
  registry:2