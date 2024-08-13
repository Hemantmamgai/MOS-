#!/bin/bash

# Check if required tools are installed
for cmd in ping iperf bc; do
  if ! command -v $cmd &> /dev/null; then
    echo "$cmd is required but not installed. Please install it and try again."
    exit 1
  fi
done

# Check for required arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <server-ip> <num-pings>"
  exit 1
fi

SERVER_IP=$1
NUM_PINGS=$2

# Function to calculate average value from ping output
calculate_avg_ping() {
  local output="$1"
  echo "$output" | grep "avg" | awk -F'/' '{print $5}'
}

# Measure latency and packet loss using ping
echo "Pinging $SERVER_IP..."
ping_output=$(ping -c $NUM_PINGS $SERVER_IP)

# Extract average latency and packet loss
avg_latency=$(calculate_avg_ping "$ping_output")
packet_loss=$(echo "$ping_output" | grep -oP '\d+(?=% packet loss)')

if [ -z "$avg_latency" ]; then
  echo "Failed to get latency. Ensure that the target server is reachable."
  exit 1
fi

if [ -z "$packet_loss" ]; then
  packet_loss=0
fi

echo "Average Latency: $avg_latency ms"
echo "Packet Loss: $packet_loss%"

# Measure jitter using iperf
echo "Measuring jitter using iperf..."
iperf_output=$(iperf -c $SERVER_IP -u -b 1M -t 10 -i 1 | grep -i "jitter" | tail -1)
jitter=$(echo "$iperf_output" | awk '{print $4}' | sed 's/ms//')

if [ -z "$jitter" ]; then
  echo "Failed to get jitter. Ensure that iperf server is running and reachable."
  exit 1
fi

echo "Jitter: $jitter ms"

# Calculate R-Factor
R=$(echo "scale=2; 93.2 - ($avg_latency + 2 * $jitter) - ($packet_loss * 2.5)" | bc)

# Calculate MOS
MOS=$(echo "scale=2; 1 + 0.035 * $R + ($R * ($R - 60) * (100 - $R)) / (7 * 10^5)" | bc)

echo "R-Factor: $R"
echo "MOS: $MOS"
