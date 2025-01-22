stmm = 201801;
endmm = 201812;

%stmm = 201901;
%endmm = 201912;

rtid = loaddata('rt_byti', stmm, endmm, 2);
rton = loaddata('rt_byti', stmm, endmm, 1);
rtxmid = loaddata('rtxm_byti', stmm, endmm, 2);
rtxmon = loaddata('rtxm_byti', stmm, endmm, 1);
rron = loaddata('rrirpnxm_byti', stmm, endmm, 1);
rrid = loaddata('rrirpnxm_byti', stmm, endmm, 2);
cfid = loaddata('cfirpnxm_byti', stmm, endmm, 2);
cfon = loaddata('cfirpnxm_byti', stmm, endmm, 1);
dayidx = 1:size(rtid,2);

rtlstnt = rton(:, dayidx(1:end-1)); %return last night = return overnight 
rtxmlstnt = rtxmon(:, dayidx(1:end-1));
rrlstnt = rron(:, dayidx(1:end-1));
cflstnt = cfon(:, dayidx(1:end-1));

rttod = rtid(:, dayidx(1:end-1));
rtxmtod = rtxmid(:, dayidx(1:end-1));
rrtod = rrid(:, dayidx(1:end-1));
cftod = cfid(:, dayidx(1:end-1));

rtton = rton(:, dayidx(2:end));
rtxmton = rtxmon(:, dayidx(2:end));
rrton = rron(:, dayidx(2:end));
cfton = cfon(:, dayidx(2:end));

rttmw = rtid(:, dayidx(2:end));
rtxmtmw = rtxmid(:, dayidx(2:end));
rrtmw = rrid(:, dayidx(2:end));
cftmw = cfid(:, dayidx(2:end));

good = loaddata('good_now', stmm, endmm);
good2 = good(:, dayidx(1:end-1)) & good(:, dayidx(2:end)) == 1;
good2 = good2 & ~isnan(rtlstnt) & ~isnan(rtxmlstnt) & ~isnan(rrlstnt) & ~isnan(cflstnt);
good2 = good2 & ~isnan(rttod) & ~isnan(rtxmtod) & ~isnan(rrtod) & ~isnan(cftod);
good2 = good2 & ~isnan(rtton) & ~isnan(rtxmton) & ~isnan(rrton) & ~isnan(cfton);
good2 = good2 & ~isnan(rttmw) & ~isnan(rtxmtmw) & ~isnan(rrtmw) & ~isnan(cftmw);

clear tb;
tbl.name = sprintf('%d_%d', stmm, endmm);
tbl.colnames = {'rt' 'rtxm' 'rr' 'cf'};
tbl.rownames = {'rtxm: lstnt -> today' 'rtxm: lstnt -> tonight' 'rtxm: today -> tmw' 'rt: lstnt -> today' 'rt: lstnt -> tonight' 'rt: today -> tmw'};
tbl.dec = 4;
tbl.mult = 1;
tbl.prcnt = 0;
tbl.data = tbldata(tbl);

tbl.data(1, 1) = regress(rtxmtod(good2), rtlstnt(good2));
tbl.data(1, 2) = regress(rtxmtod(good2), rtxmlstnt(good2));
tbl.data(1, 3) = regress(rtxmtod(good2), rrlstnt(good2));
tbl.data(1, 4) = regress(rtxmtod(good2), cflstnt(good2));

tbl.data(2, 1) = regress(rtxmton(good2), rtlstnt(good2));
tbl.data(2, 2) = regress(rtxmton(good2), rtxmlstnt(good2));
tbl.data(2, 3) = regress(rtxmton(good2), rrlstnt(good2));
tbl.data(2, 4) = regress(rtxmton(good2), cflstnt(good2));

tbl.data(3, 1) = regress(rtxmtmw(good2), rttod(good2));
tbl.data(3, 2) = regress(rtxmtmw(good2), rtxmtod(good2));
tbl.data(3, 3) = regress(rtxmtmw(good2), rrtod(good2));
tbl.data(3, 4) = regress(rtxmtmw(good2), cftod(good2));

tbl.data(4, 1) = regress(rttod(good2), rtlstnt(good2));
tbl.data(4, 2) = regress(rttod(good2), rtxmlstnt(good2));
tbl.data(4, 3) = regress(rttod(good2), rrlstnt(good2));
tbl.data(4, 4) = regress(rttod(good2), cflstnt(good2));

tbl.data(5, 1) = regress(rtton(good2), rtlstnt(good2));
tbl.data(5, 2) = regress(rtton(good2), rtxmlstnt(good2));
tbl.data(5, 3) = regress(rtton(good2), rrlstnt(good2));
tbl.data(5, 4) = regress(rtton(good2), cflstnt(good2));

tbl.data(6, 1) = regress(rttmw(good2), rttod(good2));
tbl.data(6, 2) = regress(rttmw(good2), rtxmtod(good2));
tbl.data(6, 3) = regress(rttmw(good2), rrtod(good2));
tbl.data(6, 4) = regress(rttmw(good2), cftod(good2));

dc(prnttable(tbl));