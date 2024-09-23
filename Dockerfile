ARG base_image

FROM ${base_image}

RUN apt update && apt upgrade -y && apt install -y --no-install-recommends \
	python3 \
	python3-pip \
	wget

# get the latest straight from the source - upstream version has known vulns
RUN wget https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64 \
	&& mv jq-linux-amd64 /usr/local/bin/jq \
	&& chmod +x /usr/local/bin/jq
RUN python3 -m pip install --upgrade \
	pip \
	awscli \
	wheel \
	setuptools

ENV AWS_USE_FIPS_ENDPOINT true

ADD assets/ /opt/resource/
