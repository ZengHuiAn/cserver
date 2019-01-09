package common

// ServerPacketHeader
type ServerPacketHeader struct {
	Length uint32
	Sn     uint32
	Pid    uint64
	Flag   uint32
	Cmd    uint32
	ServerID uint32
}
const ServerPacketHeaderLength =28

// ClientPacketHeader
type ClientPacketHeader struct {
	Length uint32
	Flag   uint32
	Cmd    uint32
}
const ClientPacketHeaderLength =12

// make header
func MakeAmfHeader(pid uint64, sn, cmd uint32)ClientPacketHeader{
	return ClientPacketHeader{ Flag : 1, Cmd : cmd }
}
