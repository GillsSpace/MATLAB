stmonth = 201801;
endmonth = 201812;

rtxmon = loaddata('rtxm_byti', stmonth, endmonth, 1);
rtxmid = loaddata('rtxm_byti', stmonth, endmonth, 2);
rron = loaddata('rrirpnxm_byti', stmonth, endmonth, 1);
cfon = loaddata('cfirpnxm_byti', stmonth, endmonth, 1);
good = loaddata('good_now', stmonth, endmonth);

good2 = (good == 1) & ~isnan(rtxmon) & ~isnan(rtxmid);

coefrtxm = regress(rtxmid(good2), rtxmon(good2))
coefrr = regress(rtxmid(good2), rron(good2))
coefcf = regress(rtxmid(good2), cfon(good2))