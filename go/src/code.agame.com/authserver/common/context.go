package common

// Context
type Context struct {
	*SendBuffer
	LocalAddrString string
	RemoteAddrString string
}

func NewContext(send_buffer *SendBuffer, local_addr, remote_addr string)*Context{
	return &Context{ SendBuffer : send_buffer, LocalAddrString : local_addr, RemoteAddrString : remote_addr }
}
