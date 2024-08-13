#!/bin/bash

# Check if required tools are installed
for cmd in ping bc; do
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
  echo "$output" | grep "rtt min/avg/max/mdev" | awk -F'/' '{print $5}'
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

# Extract RTT values from ping output
rtt_values=($(echo "$ping_output" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}'))

# Calculate jitter
sum_diff=0
count=0

for ((i=1; i<${#rtt_values[@]}; i++)); do
  diff=$(echo "${rtt_values[$i]} - ${rtt_values[$i-1]}" | bc | awk '{print ($1 < 0) ? -$1 : $1}')
  sum_diff=$(echo "$sum_diff + $diff" | bc)
  count=$((count + 1))
done

if [ $count -eq 0 ]; then
  jitter=0
else
  jitter=$(echo "scale=2; $sum_diff / $count" | bc)
fi

echo "Jitter: $jitter ms"

# Calculate delay impairment factor (Id) and equipment impairment factor (Ie)
# Note: The following are simplified calculations.
Ta=$(echo "scale=2; $avg_latency / 2" | bc)  # Assumed one-way delay
Ie=10  # Assumed value for G.711 codec, you can adjust based on the codec
Id=$(echo "scale=2; (0.024 * $Ta) + (0.11 * ($Ta - 177) * ($Ta > 177))" | bc)

# Calculate R-Factor
R=$(echo "scale=2; 94.2 - $Id - $Ie - ($packet_loss * 2.5)" | bc)

# Calculate MOS using the R-Factor
MOS=$(echo "scale=2; if ($R > 0) { if ($R < 100) { 1 + 0.035 * $R + $R * ($R - 60) * (100 - $R) / 7e5 } else { 4.5 } } else { 1 }" | bc)

echo "R-Factor: $R"
echo "MOS: $MOS"
