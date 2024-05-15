SELECT env('USDT',                                                  '0x1e4a5963abfd975d8c9021ce480b42188849d41d');
SELECT env('WOKB',                                                  '0xe538905cf8410324e03a5a23c1c177a474d59b2b');
SELECT env('WETH',                                                  '0x5a77f1443d16ee5761d310e38b62f77f726bc71c');
SELECT env('v2:WOKB/USDT',                                          '0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798');
SELECT env('v3:WOKB/USDT',                                          '0x11e7c6ff7ad159e179023bb771aec61db6d9234d');
SELECT env('v3:WETH/USDT',                                          '0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a');

SELECT env('swap:point',                                            '15');
SELECT env('liquidity:point',                                       '1');

SELECT env('0x1e4a5963abfd975d8c9021ce480b42188849d41d:name',       'USDT');
SELECT env('0xe538905cf8410324e03a5a23c1c177a474d59b2b:name',       'WOKB');
SELECT env('0x5a77f1443d16ee5761d310e38b62f77f726bc71c:name',       'WETH');
SELECT env('0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798:name',       'v2:WOKB/USDT');
SELECT env('0x11e7c6ff7ad159e179023bb771aec61db6d9234d:name',       'v3:WOKB/USDT');
SELECT env('0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a:name',       'v3:WETH/USDT');

SELECT env('0x1e4a5963abfd975d8c9021ce480b42188849d41d:decimals',   '6');
SELECT env('0xe538905cf8410324e03a5a23c1c177a474d59b2b:decimals',   '18');
SELECT env('0x5a77f1443d16ee5761d310e38b62f77f726bc71c:decimals',   '18');

SELECT env('referral:points',                                       '0.1');
