package common

// ServerPacketHeader
type ServerPacketHeader struct {
	Length uint32
	Sn     uint32
	Pid    uint32
	Flag   uint32
	Cmd    uint32
}
const ServerPacketHeaderLength =20

// ClientPacketHeader
type ClientPacketHeader struct {
	Length uint32
	Flag   uint32
	Cmd    uint32
}
const ClientPacketHeaderLength =12

// make header
func MakeAmfHeader(pid, sn, cmd uint32)ClientPacketHeader{
	return ClientPacketHeader{ Flag : 1, Cmd : cmd }
}
