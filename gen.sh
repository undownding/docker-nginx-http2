#!/bin/sh

parse_json_from_url() {
    curl $1 | jq ".pkgver" | sed 's/\"//g'
}

url_nginx='https://www.archlinux.org/packages/extra/x86_64/nginx-mainline/json/'
url_openssl='https://www.archlinux.org/packages/core/x86_64/openssl/json/'
url_zlib='https://www.archlinux.org/packages/core/x86_64/zlib/json/'
url_pcre='https://www.archlinux.org/packages/core/x86_64/pcre/json/'
url_geoip='https://www.archlinux.org/packages/extra/x86_64/geoip/json/'

# Get verison by ArchLinux api
version_nginx=$(parse_json_from_url $url_nginx)
version_openssl=$(echo $(parse_json_from_url $url_openssl) | sed 's/\(.*\)\.\(.*\)/\1\2/')
version_zlib=$(parse_json_from_url $url_zlib)
version_pcre=$(parse_json_from_url $url_pcre)
version_geoip=$(parse_json_from_url $url_geoip)

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
