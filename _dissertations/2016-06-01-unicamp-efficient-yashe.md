---
title: "Efficient GPGPU implementation of the Leveled Fully Homomorphic Encryption scheme YASHE"
collection: publications
permalink: /publication/2016-06-01-unicamp-efficient-yashe.md
abstract: 'Security in cloud computing is a relevant topic for research. Multiple branches of industry are embracing this paradigm to reduce operational costs, improve scalability and availability. Surprisingly, several techniques are still missing to properly preserve privacy on the cloud. Employing encryption for data storage and transport is not enough once the data owner has no real control over the processing hardware. This way, security requirements must also be extended to data processing tasks. Homomorphic encryption schemes are natural candidates for computation over encrypted data, since they are able to satisfy the requirements imposed by the cloud environment. This work investigates strategies to efficiently implement the leveled fully homomorphic scheme YASHE. It employs the CUDA platform to provide parallel processing capabilities and the chinese remainder theorem to replace expensive big integer arithmetic by simpler instructions natively supported in hardware. Moreover, this work offers a comparison between the Fast Fourier transform and the Number-Theoretic transform for reducing the complexity of polynomial multiplication. The former is provided by the cuFFT library, while the latter is implemented through the Stockham formulation. As result of this research, the cuYASHE library was developed and made available to the community. When compared with the state-of-the-art implementation in CPU, GPU and FPGA, it shows speed-ups for all operations. In particular, there was an improvement between 6 and 35 times for polynomial multiplication. This operation is performance-critical for evaluating any function over encrypted data, demonstrating that GPUs are an appropriate technology for bootstrapping privacy-preserving cloud computing environments.'
date: 2016-06-01
venue: 'Institute of Computing from University of Campinas'
url_slug: '2016-ctdseg-efficient-yashe'
paperurl: 'https://pdroalves.github.io/files/publications/2016-06-09-dissertation.pdf'
bibtexurl: ''
inportuguese: true
---

