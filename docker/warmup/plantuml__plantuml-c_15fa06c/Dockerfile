FROM key4127/refactor-dockerhub:plantuml__plantuml-c_15fa06c

# Some upstream images carry a build-time HTTP proxy in their ENV. It is not reachable outside the
# build site, so clear it for the agent, the verifier and the warm-up step below.
ENV http_proxy="" https_proxy="" HTTP_PROXY="" HTTPS_PROXY="" no_proxy="" NO_PROXY="" all_proxy="" ALL_PROXY=""

WORKDIR /testbed
RUN mkdir -p /logs

# Fill dependency caches the offline eval needs (see adapter.py NEEDS_WARMUP).
COPY warmup_eval.sh /tmp/warmup_eval.sh
COPY warmup.sh /tmp/warmup.sh
RUN bash /tmp/warmup.sh && rm -f /tmp/warmup.sh /tmp/warmup_eval.sh
