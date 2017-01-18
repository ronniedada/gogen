# Todo

* Add md5sum for gogen exe's and download new gogen from modinput if md5sum does not match
* Add timemultiple
* Consider finding a way to break up config package and refactor using better interface design
* Unit test coverage 90%
* Implement checkpointing state
    * Create channels back to each imer thread
    * Outputters should acknowledge output and that should increment state counters
    * Each timer thread should write current state after ack
    * This can also be used for performance counters