
for i in {1..10}; do
    expect dhcp.exp 10.0.5.231 4001 10.0.4.189
#    expect fwcheck.exp 10.0.5.231 4001 10.0.4.189
done

