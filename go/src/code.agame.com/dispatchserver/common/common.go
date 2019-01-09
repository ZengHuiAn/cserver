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
