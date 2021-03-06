#!/usr/bin/gawk
# USAGE: cat register_log | gawk --non-decimal-data -v clock=40 -v header=1 -f parse_trace.awk

# empty values are filled with 'NA' (not assigned)
# Thomas Huehn 2015

BEGIN{
	# set fild seperator
	FS=",";

	# mac clock rate, if not specifyed at script start, default is 40 (=40MHz clock for 802.11 a)
	if (clock == "")
		MHz = 40;
	else
		MHz = clock;

	#check if header should be printed
	if (header == 1)
	    print "ktime d_tx d_rx d_idle d_others";
}
{
#
if (NR == 1) {
	#sub(/0/,"",$1);	#delete leading zeros
	#sub(/0/,"",$2);	#delete leading zeros
	time            = strtonum($1)*1000000000 + strtonum($2) 
#	time		= $1$2;
#	first_timestamp = $1$2;
	full_tsf_old	= $3;	#64bit tsf in$3
	sub(/0*/,"",$3);	#delete leading zeros
	tsf_1_old	= strtonum(sprintf("%d", $3));
	mac_old		= sprintf("%d", $4);
	tx_old		= sprintf("%d", $5);
	rx_old		= sprintf("%d", $6);
	ed_old		= sprintf("%d", $7);
	mib_reset	= 0;
	prev_error  = 0;
}
else if (NR > 1) {
	#check if valid input at timestamp
	cur_time = $1$2;
	cur_time = strtonum($1)*1000000000 + strtonum($2)
	if (cur_time ~ /[^[:digit:]]/)
		next

	#delete leading zeros in kernel timestamp at $1$2 and tsf at$3 
#	sub(/0/,"",$1);
#	sub(/0/,"",$2);
#	cur_time = $1$2;
	cur_time = strtonum($1)*1000000000 + strtonum($2)
	full_tsf = $3;		#64bit tsf in$3
	sub(/0*/,"",$3);

	#kernel time_diff in usec
	if(prev_error == 0){
		if(strtonum(cur_time) - strtonum(time) <= 0){
			k_time_diff	= "NA";
			prev_error	= 1;
		}
		else{
			k_time_diff  =  sprintf("%.0f",(strtonum(cur_time) - strtonum(time))/1000);
		}
	}
	else {
		k_time_diff	= "NA";
		prev_error	= 0;
	}

	#tsf diff
	tsf_1 = strtonum(sprintf("%d", $3));
	if (tsf_1  > tsf_1_old){
		tsf_1_diff	= tsf_1 - tsf_1_old;
		#check plausibility of delta_tsf exeeds 2x k_time
		if (k_time_diff != "NA" && tsf_1_diff > k_time_diff * 2){
			tsf_1_diff	= "NA";
		}
	}
	else {
		tsf_1_diff	= "NA";
	}

	# read duration of our two MIB register readings in usec
	read_duration	= sprintf("%d",  $7) - sprintf("%d",  substr(full_tsf,9,8));

	# mac state calculation: d_tx = absolute delta in mac ticks, r_tx = relative delta in percent
	if (sprintf("%d", $4) + 0 > mac_old + 0) {
		d_mac = sprintf("%d", $4) - mac_old;

		#calculate tx busy
		if (sprintf("%d", $5) - tx_old  <= d_mac +0){
			d_tx = sprintf("%d", $5) - tx_old;
			rel_tx	= sprintf("%.1f",d_tx / d_mac *100);
		} else {
			d_tx = 0;
			rel_tx	= sprintf("%.1f",0);
		}

		#calculate rx busy
		if (sprintf("%d", $6) - rx_old <= d_mac){
			d_rx = sprintf("%d", $6) - rx_old;
			rel_rx	= sprintf("%.1f",d_rx / d_mac *100);
		} else {
			d_rx = 0;
			rel_rx	= sprintf("%.1f",0);
		}

		#full busy
		if (sprintf("%d", $7) - ed_old <= d_mac){
			d_ed = sprintf("%d", $7) - ed_old;
			rel_ed	= sprintf("%.1f",d_ed / d_mac *100);
		} else {
			d_ed = 0;
			rel_ed	= sprintf("%.1f",0);
		}

		#calculate channel idle states
		if (d_mac - d_ed > 0) {
			d_idle	= d_mac - d_ed;
			rel_idle = sprintf("%.1f",d_idle / d_mac *100);
		} else {
			d_idle = 0;
			rel_idle = sprintf("%.1f",0);
		}

		#calculate busy states that are triggered from other sources but rx & tx
		if (d_ed - d_tx - d_rx > 0) {
			d_others = d_ed - d_tx - d_rx;
			rel_others = sprintf("%.1f",d_others / d_mac *100);
		} else {
			d_others = 0;
			rel_others = sprintf("%.1f",0);
		}
	}
	else {
		mib_reset = 1;
		d_mac = sprintf("%d", $4);
		d_tx = sprintf("%d", $5);
		d_rx = sprintf("%d", $6);
		d_ed = sprintf("%d", $7);
		#validate input data in case of a reset
		if (d_mac - d_ed > 0)
			d_idle = d_mac - d_ed
		else
			d_idle = 0;

		if (d_ed - (d_tx + d_rx) > 0)
			d_others = d_ed - (d_tx + d_rx);
		else
			d_others = 0;

		if (d_mac > 0){
			rel_tx = sprintf("%.1f",d_tx / d_mac *100);
			rel_rx = sprintf("%.1f",d_rx / d_mac *100);
			rel_ed = sprintf("%.1f",d_ed / d_mac *100);
			rel_idle = sprintf("%.1f",d_idle / d_mac *100);
			rel_others = sprintf("%.1f",d_others / d_mac *100);
		} else {
			rel_tx = "NA";
			rel_rx = "NA";
			rel_ed = "NA";
			rel_idle = "NA";
			rel_others = "NA";
		}
	}

	#final print
	#print cur_time - first_timestamp, d_tx, d_rx, d_idle, d_others
	print cur_time, d_tx, d_rx, d_idle, d_others

	#refresh lines
	time_old = time;
	time = cur_time;
	tsf_1_old = strtonum(sprintf("%d", $3));
	mac_old	= sprintf("%d", $4);
	tx_old = sprintf("%d", $5);
	rx_old = sprintf("%d", $6);
	ed_old = sprintf("%d", $7);
	mib_reset = 0;
}

}
END{

}
