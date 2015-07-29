AddressInfo(vif0 10.0.0.1 08:00:33:33:a3:eb);
AddressInfo(vif1 20.0.0.1 08:00:44:44:b4:fc);

fd0 :: FromDevice(0); 				// 0 = first NIC
fd1 :: FromDevice(1);				// 1 = second NIC

td0 :: ToDevice(0);
td1 :: ToDevice(1);

ARPquer0 :: ARPQuerier(vif0); 			// ARP Request
ARPquer1 :: ARPQuerier(vif1);

ARPres0 :: ARPResponder(vif0); 			// ARP Reply
ARPres1 :: ARPResponder(vif1);

c0 :: Classifier(12/0806 20/0001, 		// [0] ARP queries
                 12/0806 20/0002, 		// [1] ARP responses
                 12/0800,	  		// [2] IP Packet
		 -);		  		// [3] Other

c1 :: Classifier(12/0806 20/0001,
                 12/0806 20/0002,
                 12/0800,
                 -);

out0 :: Queue(10000) -> td0;
out1 :: Queue(10000) -> td1;

fd0 -> c0 -> ARPres0 -> out0;
fd1 -> c1 -> ARPres1 -> out1;

c0[1] -> [1]ARPquer0 -> out0;
c1[1] -> [1]ARPquer1 -> out1;

routing :: StaticIPLookup(20.0.0.1/32 0,
                          10.0.0.1/32 0,
                          20.0.0.0/32 0,
                          10.0.0.0/32 0,
                          20.0.0.255/32 0,
                          10.0.0.255/32 0,
                          10.0.0.0/24 1,
                          20.0.0.0/24 2,
                          0.0.0.0/0 10.0.0.10 1);  

ip :: Strip(14) ->  CheckIPHeader(INTERFACES 10.0.0.1/24 20.0.0.1/24) -> routing;

c0[2] -> Paint(0) -> ip;
c1[2] ->  Paint(1) -> ip;

tolinux :: Discard;

routing[0] -> EtherEncap(0x0800, 1:1:1:1:1:1, 2:2:2:2:2:2) -> tolinux;

routing[1] -> DropBroadcasts
           -> pt0 :: PaintTee(0)
           -> options0 :: IPGWOptions(vif0)
           -> FixIPSrc(vif0)
           -> decttl0 :: DecIPTTL
           -> frag0 :: IPFragmenter(1500)
           -> [0]ARPquer0;


routing[2] -> DropBroadcasts
	   -> pt1 :: PaintTee(1)  
           -> options1 :: IPGWOptions(vif1)  
           -> FixIPSrc(vif1)
           -> decttl1 :: DecIPTTL
           -> frag1 :: IPFragmenter(1500)
	   -> [0]ARPquer1;

pt0[1] -> ICMPError(10.0.1.1, 5, 1) -> routing;
pt1[1] -> ICMPError(10.0.2.1, 5, 1) -> routing;

options0[1] -> ICMPError(10.0.1.1, 12, 1) -> routing;
options1[1] -> ICMPError(10.0.2.1, 12, 1) -> routing;

decttl0[1] -> ICMPError(10.0.1.1, 11, 0) -> routing;
decttl1[1] -> ICMPError(10.0.2.1, 11, 0) -> routing;

frag0[1] -> ICMPError(10.0.1.1, 3, 4) -> routing;
frag1[1] -> ICMPError(10.0.2.1, 3, 4) -> routing;

c0[3] -> Discard;
c1[3] -> Discard;
