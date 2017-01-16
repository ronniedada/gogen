package outputter

import (
	"bufio"
	"crypto/tls"
	"io"
	"io/ioutil"
	"math/rand"
	"net/http"

	config "github.com/coccyx/gogen/internal"
	log "github.com/coccyx/gogen/logger"
)

type httpout struct {
	buf         *bufio.Writer
	r           *io.PipeReader
	w           *io.PipeWriter
	client 	    *http.Client
	resp        *http.Response
	initialized bool
	closed      bool
	lastS       *config.Sample
	sent        int64
	done        chan int
}

func (h *httpout) Send(item *config.OutQueueItem) error {
	if h.initialized == false {
		h.newPost(item)
		tr := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
		h.client = &http.Client{Transport: tr}
		h.initialized = true
	}
	bytes, err := io.Copy(h.buf, item.IO.R)
	if err != nil {
		return err
	}

	h.sent += bytes
	if h.sent > int64(item.S.Output.BufferBytes) {
		err := h.buf.Flush()
		if err != nil {
			return err
		}
		err = h.w.Close()
		if err != nil {
			return err
		}
		h.newPost(item)
		h.sent = 0
	}
	h.lastS = item.S
	return nil
}

func (h *httpout) Close() error {
	if !h.closed {
		err := h.buf.Flush()
		if err != nil {
			return err
		}
		err = h.w.Close()
		if err != nil {
			return err
		}
		h.closed = true
	}
	return nil
}

func (h *httpout) newPost(item *config.OutQueueItem) {
	h.r, h.w = io.Pipe()
	h.buf = bufio.NewWriter(h.w)

	endpoint := item.S.Output.Endpoints[rand.Intn(len(item.S.Output.Endpoints))]
	req, err := http.NewRequest("POST", endpoint, h.r)
	for k, v := range item.S.Output.Headers {
		req.Header.Add(k, v)
	}
	go func() {
		h.resp, err = h.client.Do(req)
		if err != nil && h.resp == nil {
			log.Errorf("Error making request from sample '%s' to endpoint '%s': %s", item.S.Name, endpoint, err)
		} else {
			defer h.resp.Body.Close()

			body, err := ioutil.ReadAll(h.resp.Body)
			if err != nil {
				log.Errorf("Error making request from sample '%s' to endpoint '%s': %s", item.S.Name, endpoint, err)
			} else if h.resp.StatusCode != 200 {
				log.Errorf("Error making request from sample '%s' to endpoint '%s', status '%d': %s", item.S.Name, endpoint, h.resp.StatusCode, body)
			}
		}
	}()
}
