package common

import(
	"bytes"
	"encoding/binary"
	"code.agame.com/pressure/amf"
	"code.agame.com/pressure/log"
)

func MakeNetPacket(header ClientPacketHeader, item interface{})([]byte, error){
	// write body
	body_bs, err := amf.EncodeAmf(item)
	if err != nil {
		log.Error("fail to MakeNetPacket, %s", err.Error())
		return nil, err
	}

	// write header
	header.Length =uint32(ClientPacketHeaderLength + len(body_bs))
	var header_buf bytes.Buffer
	if err = binary.Write(&header_buf, binary.BigEndian, &header); err != nil {
		log.Error("fail to MakeNetPacket, %s", err.Error())
		return nil, err
	}
	header_bs := header_buf.Bytes()

	// cat
	return append(header_bs, body_bs...), nil
}

func I2Int64(i interface{})int64{
	if i == nil {
		return 0
	}
	switch i.(type) {
	case float32:
		return int64(i.(float32))
	case float64:
		return int64(i.(float64))
	case int:
		return int64(i.(int))
	case int8:
		return int64(i.(int8))
	case int16:
		return int64(i.(int16))
	case int32:
		return int64(i.(int32))
	case int64:
		return int64(i.(int64))
	case uint:
		return int64(i.(uint))
	case uint8:
		return int64(i.(uint8))
	case uint16:
		return int64(i.(uint16))
	case uint32:
		return int64(i.(uint32))
	case uint64:
		return int64(i.(uint64))
	default:
		return 0
	}
}

func I2Uint64(i interface{})uint64{
	if i == nil {
		return 0
	}
	switch i.(type) {
	case float32:
		return uint64(i.(float32))
	case float64:
		return uint64(i.(float64))
	case int:
		return uint64(i.(int))
	case int8:
		return uint64(i.(int8))
	case int16:
		return uint64(i.(int16))
	case int32:
		return uint64(i.(int32))
	case int64:
		return uint64(i.(int64))
	case uint:
		return uint64(i.(uint))
	case uint8:
		return uint64(i.(uint8))
	case uint16:
		return uint64(i.(uint16))
	case uint32:
		return uint64(i.(uint32))
	case uint64:
		return uint64(i.(uint64))
	default:
		return 0
	}
}

func I2Float64(i interface{})float64{
	if i == nil {
		return 0
	}
	switch i.(type) {
	case float32:
		return float64(i.(float32))
	case float64:
		return float64(i.(float64))
	case int:
		return float64(i.(int))
	case int8:
		return float64(i.(int8))
	case int16:
		return float64(i.(int16))
	case int32:
		return float64(i.(int32))
	case int64:
		return float64(i.(int64))
	case uint:
		return float64(i.(uint))
	case uint8:
		return float64(i.(uint8))
	case uint16:
		return float64(i.(uint16))
	case uint32:
		return float64(i.(uint32))
	case uint64:
		return float64(i.(uint64))
	default:
		return 0
	}
}
func I2String(i interface{})string{
	if i == nil {
		return ""
	}
	switch i.(type) {
	case string:
		return i.(string)
	default:
		return ""
	}
}
func I2Array(i interface{})[]interface{}{
	if i == nil {
		return nil
	}
	switch i.(type) {
	case []interface{}:
		return i.([]interface{})
	default:
		return nil
	}
}
