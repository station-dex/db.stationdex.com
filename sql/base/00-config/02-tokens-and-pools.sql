DELETE FROM environment_variables;

-- common

SELECT env('swap:point',                                                '15');
SELECT env('liquidity:point',                                           '1');
SELECT env('referral:points',                                           '0.1');

-- X Layer Mainnet: 196

SELECT env('196:USDT',                                                  '0x1e4a5963abfd975d8c9021ce480b42188849d41d');
SELECT env('196:WOKB',                                                  '0xe538905cf8410324e03a5a23c1c177a474d59b2b');
SELECT env('196:WETH',                                                  '0x5a77f1443d16ee5761d310e38b62f77f726bc71c');
SELECT env('196:v2:WOKB/USDT',                                          '0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798');
SELECT env('196:v3:WOKB/USDT',                                          '0x11e7c6ff7ad159e179023bb771aec61db6d9234d');
SELECT env('196:v3:WETH/USDT',                                          '0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a');

SELECT env('196:0x1e4a5963abfd975d8c9021ce480b42188849d41d:name',       'USDT');
SELECT env('196:0xe538905cf8410324e03a5a23c1c177a474d59b2b:name',       'WOKB');
SELECT env('196:0x5a77f1443d16ee5761d310e38b62f77f726bc71c:name',       'WETH');
SELECT env('196:0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798:name',       'v2:WOKB/USDT');
SELECT env('196:0x11e7c6ff7ad159e179023bb771aec61db6d9234d:name',       'v3:WOKB/USDT');
SELECT env('196:0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a:name',       'v3:WETH/USDT');

SELECT env('196:0x1e4a5963abfd975d8c9021ce480b42188849d41d:decimals',   '6');
SELECT env('196:0xe538905cf8410324e03a5a23c1c177a474d59b2b:decimals',   '18');
SELECT env('196:0x5a77f1443d16ee5761d310e38b62f77f726bc71c:decimals',   '18');

SELECT env('196:contracts', '{0xa91f3e6935859d3333c4e528e74f3284124dcf51,0x90Abedb3F1d1ea4f945153440Db7AC8B74e81BAc ,0xf89f39e39cf07f6862c084c2e1dbc913b521263a ,0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798 ,0x11e7c6ff7ad159e179023bb771aec61db6d9234d ,0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a}');

-- X Layer Testnet: 195

SELECT env('195:WOKB',                                                  '0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6');
SELECT env('195:USDT',                                                  '0xeb45D32425a02a5A9d8500375932f1cCe5781b96');
SELECT env('195:USDC',                                                  '0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248');
SELECT env('195:v3:WOKB/USDC',                                          '0x725b0caa0a38564b90e9ce608e037e2556de4f87');
SELECT env('195:v2:USDC/USDT',                                          '0x388c8ca45bccf0c430ef6955a526b1dc1bab765a');
SELECT env('195:v3:USDC/USDT',                                          '0x26f007e7c978856a70f8d2e8a79300496e96a1ba');

SELECT env('195:0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6:name',       'WOKB');
SELECT env('195:0xeb45D32425a02a5A9d8500375932f1cCe5781b96:name',       'USDT');
SELECT env('195:0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248:name',       'USDC');
SELECT env('195:0x725b0caa0a38564b90e9ce608e037e2556de4f87:name',       'v3:WOKB/USDC');
SELECT env('195:0x388c8ca45bccf0c430ef6955a526b1dc1bab765a:name',       'v2:USDC/USDT');
SELECT env('195:0x26f007e7c978856a70f8d2e8a79300496e96a1ba:name',       'v3:USDC/USDT');

SELECT env('195:0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6:decimals',   '18');
SELECT env('195:0xeb45D32425a02a5A9d8500375932f1cCe5781b96:decimals',   '18');
SELECT env('195:0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248:decimals',   '6');

SELECT env('195:contracts', '{0x5182e0fcb8619f41c0f40da342b4dc82c088f5e5, 0xa639d6f6437a487201f414d787fdcacfa627b007, 0x0623806922db8bfe8a5d0996c73ea2fb5999ee82, 0x6e19cb93b94433f59a3257b6e995b95e655e09a2}');

