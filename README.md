# parakeet-lowmem

A memory-saving patch for the speech-to-text backend in LocalAI, packaged as an image LocalAI can install. It is a patch on top of LocalAI's parakeet-cpp backend. It is not parakeet-cpp itself, and it is not upstream.

With the patch, one hour of audio with three speakers fits in a 2.5 GB memory cap. Without it, the same recording needs about 8 GB.

## What this is

[LocalAI](https://github.com/mudler/LocalAI) is a program that runs AI models on your own server. Its parakeet-cpp backend turns recordings into text and can label who is speaking. On a long recording that backend holds the whole thing in memory at once. This patch makes it read the audio in blocks, transcribe in overlapping windows, and feed the speaker model in pieces.

The image here is LocalAI's own parakeet-cpp backend image with one file replaced: the rebuilt `parakeet-cpp-grpc` program. Everything else (`run.sh`, the libraries) is upstream's, untouched.

## Install it in LocalAI

In LocalAI's web page, open Backends, then install from an image:

- URI: `oci://ghcr.io/tortoisewolfe/parakeet-lowmem:v4.11.0-1`
- Name: `cpu-parakeet-cpp`
- Alias: `parakeet-cpp`

The same thing through the API:

```
curl -X POST http://localhost:8080/api/backends/install-external \
  -H 'Content-Type: application/json' \
  -d '{"uri":"oci://ghcr.io/tortoisewolfe/parakeet-lowmem:v4.11.0-1","name":"cpu-parakeet-cpp","alias":"parakeet-cpp"}'
```

It answers with a job ID. Watch it at `/api/backends/job/<jobID>` until it says `"processed":true`.

Then set these on the LocalAI service. They do nothing without the patch:

```
PARAKEET_ATT_CONTEXT=128
PARAKEET_SUBSAMPLING_TILE=1024
```

And give the model these options:

```
asr_window_seconds:300
asr_window_overlap_seconds:20
diarization_feed_seconds:60
diarization_model:parakeet-cpp/nemotron-3-diarization-q8_0.gguf
```

## What it measured

One hour, three speakers, 2560 MB cap, 4 processors:

- Peak memory 2.0 to 2.2 GB over three runs, 4 to 5 minutes of run time.
- Every segment got the right speaker label.
- Without the patch: 7.6 GB.

Install check, 8 Nov 2026: the published `v4.11.0-1` image, pulled with no login, was installed into a fresh LocalAI v4.11.0 with the call above. A 15 minute, six speaker recording of public read speech (LibriSpeech dev-clean) then ran under a 2560 MB cap. Peak memory was 1.91 GB, including the install, with 126 segments and a word error rate of 2.66%, the same as the earlier build. No cut dropped or repeated a word.

Windows test, public read speech (LibriSpeech dev-clean, 15 to 22 minutes):

- At 300 second windows, ten cuts lost and repeated nothing.
- A 60 second stress test cut through continuous speech 79 times and lost two words once.
- Three recordings, one machine, one run each. Meeting speech with crosstalk will have a higher error rate.

## Where it comes from

- LocalAI, MIT license, copyright Ettore Di Giacinto. The patch applies to commit `58830f7ac508845a6f4efa32cfca06af422d4d82`, which is release v4.11.0. The Dockerfile fetches that exact commit.
- parakeet.cpp ([mudler/parakeet.cpp](https://github.com/mudler/parakeet.cpp)), MIT license. It is the library inside the upstream backend image.
- The model weights are NVIDIA's, with their own licenses. They are not in this image.
- The patch is mine and is MIT licensed too. It has not been sent upstream.

## Why this is its own repo

LocalAI installs a backend by pulling a published image, so the image has to live at a public address. The Chattanooga.Digital co-op keeps no forks of other projects, so the patch and the build live here and the co-op's repo only links to the image.

## Build it yourself

```
docker build -t ghcr.io/tortoisewolfe/parakeet-lowmem:v4.11.0-1 .
```

Pushing a tag that starts with `v` builds and publishes the image from GitHub Actions. A pull request or a push to main builds it without publishing.
