conda activate base

echo '======== build fronted ========'
cd ./frontend
npm run build
echo '======== build success ========'
cd ..
npm run rd
npm run clean
npm run encrypt
#npm run start
echo '======== build win ========'
# win
npm run build-wz-64
npm run build-wz-32

