if [ -n "$1" ];
then
    DCVERSION=$1
    echo "Try to download docker compose version '$DCVERSION'."
else
    DCVERSION="v2.2.3"
    echo "No parameter for version is provided. Default '$DCVERSION' is set."
fi

mkdir ~/dc-work-$DCVERSION
curl -o ~/dc-work-$DCVERSION/docker-compose -kL "https://github.com/docker/compose/releases/download/$DCVERSION/docker-compose-linux-x86_64"
chmod +x ~/dc-work-$DCVERSION/docker-compose
mkdir -p ~/.docker/cli-plugins/
mv -f ~/dc-work-$DCVERSION/docker-compose ~/.docker/cli-plugins/
rmdir ~/dc-work-$DCVERSION
