#!/bin/bash -e

# change the following variables to match your new coin
COIN_NAME="Moneta"
COIN_UNIT="MNTA"
# 42 million coins at total (litecoin total supply is 84000000)
# TOTAL_SUPPLY=420000000
MAINNET_PORT="47890"
TESTNET_PORT="47891"
REGTEST_PORT="47892"
# leave CHAIN empty for main network, -regtest for regression network and -testnet for test network
CHAIN="-regtest"
# CHAIN="-testnet"
# CHAIN=""
ACCEPT_MINERS=false

# dont change the following variables unless you know what you are doing
MONETA_BRANCH=0.18
GENESISHZERO_REPOS=https://github.com/mmontuori/GenesisH0.git
LITECOIN_REPOS=https://github.com/mmontuori/moneta.git
COIN_NAME_LOWER=$(echo $COIN_NAME | tr '[:upper:]' '[:lower:]')
COIN_NAME_UPPER=$(echo $COIN_NAME | tr '[:lower:]' '[:upper:]')
COIN_UNIT_LOWER=$(echo $COIN_UNIT | tr '[:upper:]' '[:lower:]')
DIRNAME=$(dirname $0)
DOCKER_NETWORK="172.18.0"
DOCKER_IMAGE_LABEL="mnta-env"
OSVERSION="$(uname -s)"

docker_build_image()
{
    IMAGE=$(docker images -q $DOCKER_IMAGE_LABEL)
    if [ -z $IMAGE ]; then
        echo Building docker image
        if [ ! -f $DOCKER_IMAGE_LABEL/Dockerfile ]; then
            mkdir -p $DOCKER_IMAGE_LABEL
            cat <<EOF > $DOCKER_IMAGE_LABEL/Dockerfile
FROM ubuntu:18.04
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true
RUN truncate -s0 /tmp/preseed.cfg
RUN echo "tzdata tzdata/Areas select America" >> /tmp/preseed.cfg
RUN echo "tzdata tzdata/Zones/America select New_York" >> /tmp/preseed.cfg
RUN debconf-set-selections /tmp/preseed.cfg
RUN rm -f /etc/timezone /etc/localtime
RUN apt update
RUN apt install -y tzdata
RUN apt install -y libterm-readline-gnu-perl
RUN apt install -y apt-utils
RUN apt install -y gnupg
RUN apt -y upgrade
RUN apt install -y build-essential libboost-all-dev libssl-dev libtool autotools-dev automake pkg-config bsdmainutils python3 software-properties-common
RUN echo deb http://ppa.launchpad.net/bitcoin/bitcoin/ubuntu xenial main >> /etc/apt/sources.list
RUN sleep 10;apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv D46F45428842CE5E
RUN apt update
RUN apt-get install -y ccache git libboost-system1.62.0 libboost-filesystem1.62.0 libboost-program-options1.62.0 libboost-thread1.62.0 libboost-chrono1.62.0 libssl1.1 libevent-pthreads-2.1.6 libevent-2.1.6 build-essential libssl-dev libevent-dev libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libzmq3-dev
RUN apt-get install -y libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libqrencode-dev libqt5gui5
RUN apt-get install -y python-pip iputils-ping net-tools libboost-all-dev curl
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
#RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
#RUN python2 get-pip.py
RUN pip install construct==2.5.2 scrypt
EOF
        fi
        docker build --label $DOCKER_IMAGE_LABEL --tag $DOCKER_IMAGE_LABEL $DIRNAME/$DOCKER_IMAGE_LABEL/
    else
        echo Docker image already built
    fi
}

docker_run_genesis()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_run()
{
    mkdir -p $DIRNAME/.ccache
    docker run \
    -v $DIRNAME/GenesisH0:/GenesisH0 \
    -v $DIRNAME/.ccache:/root/.ccache \
    -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL \
    /bin/bash -c "$1"
}

docker_stop_nodes()
{
    echo "Stopping all docker nodes"
    for id in $(docker ps -q -a  -f ancestor=$DOCKER_IMAGE_LABEL); do
        docker exec -ti $id /moneta/src/moneta-cli $CHAIN stop
    done
    for id in $(docker ps -q -a  -f ancestor=$DOCKER_IMAGE_LABEL); do
        docker stop $id
    done
    echo "y" | docker system prune >/dev/null 2>&1
}

docker_remove_nodes()
{
    echo "Removing all docker nodes"
    for id in $(docker ps -q -a  -f ancestor=$DOCKER_IMAGE_LABEL); do
        docker rm $id
    done
}

docker_create_network()
{
    echo "Creating docker network"
    if ! docker network inspect newcoin &>/dev/null; then
        docker network create --subnet=$DOCKER_NETWORK.0/16 newcoin
    fi
}

docker_remove_network()
{
    echo "Removing docker network"
    docker network rm newcoin
}

docker_run_node()
{
    local NODE_NUMBER=$1
    local NODE_COMMAND=$2
    mkdir -p $DIRNAME/miner${NODE_NUMBER}
    if [ ! -f $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf ]; then
        cat <<EOF > $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf
rpcuser=${COIN_NAME_LOWER}rpc
rpcpassword=$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 32; echo)
EOF
    fi

    port_cmd=""
    if [ "$NODE_NUMBER" == "2" ] && [ "$ACCEPT_MINERS" == "true" ]; then
        if [ "$CHAIN" == "" ]; then
            port_cmd="--expose $MAINNET_PORT --publish $MAINNET_PORT:$MAINNET_PORT"
        elif [ "$CHAIN" == "-testnet" ]; then
            port_cmd="--expose $TESTNET_PORT --publish $TESTNET_PORT:$TESTNET_PORT"
        elif [ "$CHAIN" == "-regtest" ]; then
            port_cmd="--expose $REGTEST_PORT --publish $REGTEST_PORT:$REGTEST_PORT"
        else
            echo "ERROR: CHAIN $CHAIN is not supported!"
            exit 1
        fi
    fi

    docker run \
    --net newcoin \
    $port_cmd \
    --ip $DOCKER_NETWORK.${NODE_NUMBER} \
    -v $DIRNAME/miner${NODE_NUMBER}:/root/.$COIN_NAME_LOWER \
    -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL \
    /bin/bash -c "$NODE_COMMAND"
}

clone_repo()
{
    if [ -d $COIN_NAME_LOWER ]; then
        echo "Warning: $COIN_NAME_LOWER already existing. Not replacing any values"
        return 0
    fi
    if [ ! -d "moneta-master" ]; then
        # clone litecoin and keep local cache
        git clone -b $MONETA_BRANCH $LITECOIN_REPOS moneta-master
    else
        echo "Updating master branch"
        pushd moneta-master
        git pull
        popd
    fi

    git clone -b $MONETA_BRANCH moneta-master $COIN_NAME_LOWER

}

build_moneta()
{
    # only run autogen.sh/configure if not done previously
    if [ ! -e $COIN_NAME_LOWER/Makefile ]; then
        docker_run "cd /$COIN_NAME_LOWER ; bash  /$COIN_NAME_LOWER/autogen.sh"
        docker_run "cd /$COIN_NAME_LOWER ; bash  /$COIN_NAME_LOWER/configure --disable-tests --disable-bench"
    fi
    # always build as the user could have manually changed some files
    docker_run "cd /$COIN_NAME_LOWER ; make -j2"
}


if [ $DIRNAME =  "." ]; then
    DIRNAME=$PWD
fi

cd $DIRNAME

# sanity check

case $OSVERSION in
    Linux*)
        SED=sed
    ;;
    Darwin*)
        SED=$(which gsed 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "please install gnu-sed with 'brew install gnu-sed'"
            exit 1
        fi
        SED=gsed
    ;;
    *)
        echo "This script only works on Linux and MacOS"
        exit 1
    ;;
esac


if ! which docker &>/dev/null; then
    echo Please install docker first
    exit 1
fi

if ! which git &>/dev/null; then
    echo Please install git first
    exit 1
fi

case $1 in
    stop)
        docker_stop_nodes
    ;;
    remove_nodes)
        docker_stop_nodes
        docker_remove_nodes
    ;;
    clean_up)
        docker_stop_nodes
        for i in $(seq 2 5); do
           docker_run_node $i "rm -rf /$COIN_NAME_LOWER /root/.$COIN_NAME_LOWER" &>/dev/null
        done
        docker_remove_nodes
        docker_remove_network
        rm -rf $COIN_NAME_LOWER
        if [ "$2" != "keep_genesis_block" ]; then
            rm -f GenesisH0/${COIN_NAME}-*.txt
        fi
        for i in $(seq 2 5); do
           rm -rf miner$i
        done
    ;;
    prepare)
        docker_build_image
        clone_repo 
        build_moneta
    ;;
    start)
        if [ -n "$(docker ps -q -f ancestor=$DOCKER_IMAGE_LABEL)" ]; then
            echo "There are nodes running. Please stop them first with: $0 stop"
            exit 1
        fi

        docker_run_node 2 "cd /$COIN_NAME_LOWER ; ./src/${COIN_NAME_LOWER}d $CHAIN" &

        echo "Docker containers should be up and running now. You may run the following command to check the network status:
#for i in \$(docker ps -q); do docker exec \$i /$COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN getblockchaininfo; done"
        echo "To ask the nodes to mine some blocks simply run:
#for i in \$(docker ps -q); do docker exec \$i /$COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN generate 2  & done"
        exit 1
    ;;
    *)
        cat <<EOF
Usage: $0 (start|stop|remove_nodes|clean_up)
 - prepare: bootstrap environment and build
 - start: start a single instance miner
 - stop: simply stop the containers without removing them
 - remove_nodes: remove the old docker container images. This will stop them first if necessary.
 - clean_up: WARNING: this will stop and remove docker containers and network, source code, genesis block information and nodes data directory. (to start from scratch)
EOF
    ;;
esac
