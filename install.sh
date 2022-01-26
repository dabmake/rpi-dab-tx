#    install.sh - Install the software stack
#    Copyright (C) 20222 Robin ALEXANDER
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# Update the system and install the essential tools
sudo apt update
sudo apt upgrade -y
sudo apt install -y build-essential automake libtool
pushd ${HOME}

# Create the folder containing the ODR tools
mkdir ${HOME}/ODR-mmbTools
pushd ${HOME}/ODR-mmbTools

# Install mmb-tools: audio encoder
sudo apt install -y libzmq3-dev libzmq5 libvlc-dev vlc-data vlc-plugin-base libcurl4-openssl-dev
git clone https://github.com/Opendigitalradio/ODR-AudioEnc.git
pushd ODR-AudioEnc
./bootstrap
./configure --enable-vlc
make
sudo make install
popd # back to ${HOME}/ODR-mmbTools

# Install mmb-tools: PAD encoder
sudo apt install -y libmagickwand-dev
git clone https://github.com/Opendigitalradio/ODR-PadEnc.git
pushd ODR-PadEnc
./bootstrap
./configure
make
sudo make install
popd # back to ${HOME}/ODR-mmbTools

# Install mmb-tools: dab multiplexer
sudo apt install -y libboost-system-dev libcurl4-openssl-dev
git clone https://github.com/Opendigitalradio/ODR-DabMux.git
pushd ODR-DabMux
./bootstrap.sh
## Temporary, until ODR-DabMux configure is modified
arch=$(uname -m)
if [ "${arch}" = "armv7l" ]; then
  ./configure --with-boost-libdir=/usr/lib/arm-linux-gnueabihf
else
  ./configure
fi
make
sudo make install
popd # back to ${HOME}/ODR-mmbTools

# Install mmb-tools: modulator
sudo apt install -y libfftw3-dev libsoapysdr-dev
git clone https://github.com/Opendigitalradio/ODR-DabMod.git
pushd ODR-DabMod
./bootstrap.sh
./configure CFLAGS="-O3 -DNDEBUG" CXXFLAGS="-O3 -DNDEBUG" --enable-fast-math --disable-output-uhd --disable-zeromq
make
sudo make install
popd # back to ${HOME}/ODR-mmbTools

popd # back to ${HOME}

# Copy the configuration files
if [ ! -d ${HOME}/dab ]; then
  cp -r $(realpath $(dirname $0))/dab ${HOME}
fi

# Adapt the home directory in the supervisor configuration files
sed -e "s;/home/pi;${HOME};g" -i ${HOME}/dab/supervisor/LF.conf
sed -e "s;/home/pi;${HOME};g" -i ${HOME}/dab/supervisor/HF.conf

# Install the supervisor tool
sudo apt install -y supervisor
if [ ! $(grep inet_http_server /etc/supervisor/supervisord.conf) ]; then
  cat << EOF | sudo tee -a /etc/supervisor/supervisord.conf > /dev/null

[inet_http_server]
port = 8001
username = odr ; Auth username
password = odr ; Auth password
EOF
fi
sudo ln -s $HOME/dab/supervisor/*.conf /etc/supervisor/conf.d/
sudo supervisorctl reread
sudo supervisorctl reload

popd # back to where we were when we called this script