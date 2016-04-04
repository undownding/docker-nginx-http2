#!/bin/sh

parse_json_from_url() {
    curl --connect-timeout 5 \
     --max-time 40 \
     --retry 20 \
     --retry-delay 0 $1 | jq ".pkgver" | sed 's/\"//g'
}

get_version_from_github() {
    curl --connect-timeout 5 \
     --max-time 40 \
     --retry 20 \
     --retry-delay 0 $1 | jq ".[0].name" | sed 's/\"//g'
}

url_nginx='https://api.github.com/repos/nginx/nginx/tags'
url_openssl='https://www.archlinux.org/packages/core/x86_64/openssl/json/'
url_zlib='https://www.archlinux.org/packages/core/x86_64/zlib/json/'
url_pcre='https://www.archlinux.org/packages/core/x86_64/pcre/json/'
url_geoip='https://api.github.com/repos/maxmind/geoip-api-c/tags'

# Get verison by ArchLinux api
version_nginx=$(echo $(get_version_from_github $url_nginx) | sed 's/release-//g')
version_openssl=$(echo $(parse_json_from_url $url_openssl) | sed 's/\(.*\)\.\(.*\)/\1\2/')
version_zlib=$(parse_json_from_url $url_zlib)
version_pcre=$(parse_json_from_url $url_pcre)
version_geoip=$(echo $(get_version_from_github $url_geoip) | sed 's/v//g')

if [ ! $version_nginx ]; then
    exit 0
fi

if [ ! $version_openssl ]; then
    exit 0
fi

if [ ! $version_zlib ]; then
    exit 0
fi

if [ ! $version_pcre ]; then
    exit 0
fi

if [ ! $version_geoip ]; then
    exit 0
fi

mv ./NGINX_VERSION ./OLD_NGINX_VERSION
mv ./LIBRARY_VERSION ./OLD_LIBRARY_VERSION

echo "ENV nginx_version $version_nginx" > ./NGINX_VERSION
echo "ENV openssl_version $version_openssl" > ./LIBRARY_VERSION
echo "ENV zlib_version $version_zlib" >> ./LIBRARY_VERSION
echo "ENV pcre_version $version_pcre" >> ./LIBRARY_VERSION
echo "ENV geoip_version $version_geoip" >> ./LIBRARY_VERSION

mv ./Dockerfile ./OLD_Dockerfile

# Generate a new Dockerfile
echo 'FROM debian:jessie' > ./tmp
echo >> ./tmp
cat ./NGINX_VERSION >> ./tmp
cat ./LIBRARY_VERSION >> ./tmp
echo >> ./tmp

cat ./tmp Dockerfile.tpl > Dockerfile

# New Dockerfile is different from the old one?
diff --brief ./Dockerfile ./OLD_Dockerfile >/dev/null
comp_dockerfile=$?
if [ $comp_dockerfile -eq 1 ]; then

    # Generate a new README.md
    cp ./README.md.tpl ./README.md
    sed -i "s/NGINX_VERSION/$version_nginx/g" ./README.md
    sed -i "s/OPENSSL_VERSION/$version_openssl/g" ./README.md
    sed -i "s/ZLIB_VERSION/$version_zlib/g" ./README.md
    sed -i "s/PCRE_VERSION/$version_pcre/g" ./README.md
    sed -i "s/GEOIP_VERSION/$version_geoip/g" ./README.md

    git add -u && git commit -m "Update at `date -R`"
    while ! git push origin HEAD:master; do sleep 3; done
    while ! git push coding HEAD:master; do sleep 3; done


    # If nginx version has changed, push the new one as a tag
    diff --brief ./NGINX_VERSION ./OLD_NGINX_VERSION >/dev/null
    comp_nginx=$?
    if [ $comp_nginx -eq 1 ]; then
        git tag $version_nginx
        while ! git push origin $version_nginx; do sleep 3; done
        while ! git push coding $version_nginx; do sleep 3; done
    fi
    
fi

# clean
rm ./OLD_*
rm ./tmp
