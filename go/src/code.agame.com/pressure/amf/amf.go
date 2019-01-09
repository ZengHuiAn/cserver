package amf

import (
	"io"
	"errors"
	"reflect"
	"bytes"
	"encoding/binary"
)

var ErrNotImplement  = errors.New("not implement");
var ErrType          = errors.New("error type");
var ErrU29OutOfRange = errors.New("u29 out of range");
var ErrLogLength     = errors.New("length to long");
var ErrReference     = errors.New("reference error");
var ErrReadonly      = errors.New("interface is read only");

func Encode(w io.Writer, v interface{}) (int, error) {
	ref := &ReferenceLog{Strings:make([]string,0), Bytes:make([][]byte,0)};
	return encodeWithRef(w, reflect.ValueOf(v), ref);
}

func Decode(r io.Reader) (interface{}, error) {
	ref := &ReferenceLog{Strings:make([]string,0), Bytes:make([][]byte,0)};
	return decodeWithRef(r, ref);
}

func DecodeTo(r io.Reader, v interface{}) error {
	ref := &ReferenceLog{Strings:make([]string,0), Bytes:make([][]byte,0)};
	return decodeToWithRef(r, reflect.ValueOf(v), ref);
}

func encodeWithRef(w io.Writer, value reflect.Value, ref *ReferenceLog) (int, error) {
	if value.Kind() == reflect.Ptr || value.Kind() == reflect.Interface {
		value = value.Elem();
	}

	switch value.Kind() {
		case reflect.Invalid:
			return encodeNull(w);
        case reflect.Bool:
			return encodeBool(w, value.Bool());
        case reflect.Int, reflect.Int8, reflect.Int16,
			 reflect.Int32, reflect.Int64:
			return encodeInt(w, value.Int());
        case reflect.Uint,reflect.Uint8, reflect.Uint16,
			 reflect.Uint32, reflect.Uint64:
			return encodeUint(w, value.Uint());
        case reflect.Float32, reflect.Float64:
			return encodeFloat(w, value.Float());
        case reflect.Array, reflect.Slice:
			return encodeArray(w, value, ref);
		case reflect.Struct:
			return encodeArrayWithStruct(w, value, ref);
        case reflect.String:
			return encodeString(w, value.String(), ref);
		default:
			return 0, ErrType;
	}
}

type ReferenceLog struct {
	Strings []string;
	Bytes   [][]byte;
};

func decodeWithRef(r io.Reader, ref *ReferenceLog) (interface{}, error) {
	bs := make([]byte, 1);

	_, err := r.Read(bs);
	if err != nil {
		return nil, err;
	}

	switch bs[0] {
		case amf_undefine:
			return nil, nil;
		case amf_null:
			return nil, nil;
		case amf_false:
			return false, nil;
		case amf_true:
			return true, nil;
		case amf_integer:
			return decodeInteger(r);
		case amf_double:
			return decodeFloat(r);
		case amf_string:
			return decodeString(r, ref);
		case amf_array:
			return decodeArray(r, ref);
		case amf_byte_array:
			return decodeByteArray(r, ref);
		default:
			return nil, ErrNotImplement;
	}
}

func checkKind(k reflect.Kind, t_amf byte) bool {
	if (t_amf == amf_undefine || t_amf == amf_null) {
		return true;
	}

	switch k {
		case reflect.Bool:
			return t_amf == amf_true || t_amf  == amf_false;
        case reflect.Int, reflect.Int8, reflect.Int16,
			 reflect.Int32, reflect.Int64:
			return t_amf == amf_integer;
        case reflect.Uint,reflect.Uint8, reflect.Uint16,
			 reflect.Uint32, reflect.Uint64:
			return t_amf == amf_integer;
        case reflect.Float32, reflect.Float64:
			return t_amf == amf_double;
        case reflect.Array, reflect.Slice:
			return t_amf == amf_array || t_amf == amf_byte_array;
		case reflect.Struct:
			return t_amf == amf_array;
        case reflect.String:
			return t_amf == amf_string || t_amf == amf_byte_array;
		default:
			return false;
	}
}

func decodeToWithRef(r io.Reader, value reflect.Value, ref *ReferenceLog) error {
	if value.Kind() == reflect.Ptr {
		value = value.Elem();
	}

	if !value.CanSet() {
		return ErrReadonly;
	}

	bs := make([]byte, 1);
	_, err := r.Read(bs);
	if err != nil {
		return err;
	}

	if !checkKind(value.Kind(), bs[0]) {
		return ErrType;
	}

	switch bs[0] {
		case amf_undefine, amf_null:
			value.Set(reflect.Zero(value.Type()));
		case amf_false:
			value.SetBool(false);
		case amf_true:
			value.SetBool(true);
		case amf_integer:
			i, err := decodeInteger(r);;
			if err != nil {
				return err;
			}

			switch value.Kind() {
				case reflect.Int, reflect.Int8, reflect.Int16,
					 reflect.Int32, reflect.Int64:
						 value.SetInt(i);

				case reflect.Uint,reflect.Uint8, reflect.Uint16,
					 reflect.Uint32, reflect.Uint64:
						 if i > 0 {
							 value.SetUint(uint64(i));
						 } else {
							 return ErrType;
						 }
				default:
				return ErrType;
			}
		case amf_double:
			d, err := decodeFloat(r);
			if err != nil {
				return err;
			}

			value.SetFloat(d);
			return err;
		case amf_string:
			s, err := decodeString(r, ref);
			if err != nil {
				return err;
			}
			switch value.Interface().(type) {
				case []byte:
					value.SetBytes([]byte(s));
				case string:
					value.SetString(s);
				default:
					return ErrType;
			}
		case amf_byte_array:
			bs, err := decodeByteArray(r, ref);
			if err != nil {
				return err;
			}
			switch value.Interface().(type) {
				case []byte:
					value.SetBytes(bs);
				case string:
					value.SetString(string(bs));
				default:
					return ErrType;
			}
		case amf_array:
			return decodeArrayTo(r, value, ref);
		default:
			return ErrType;
	}
	return nil;
}

func writeAmfType(w io.Writer, t byte) (int, error) {
	return w.Write([]byte{t});
}

func encodeBool(w io.Writer, value bool) (int, error) {
	if value {
		return writeAmfType(w, amf_true);
	} else {
		return writeAmfType(w, amf_false);
	}
}

func encodeNull(w io.Writer) (int, error) {
	return writeAmfType(w, amf_null);
}

const AMF_INTEGER_MAX = 0xFFFFFFF;

// signed int -> uint29
func s2u(i int32) uint32 {
	if i > 0xFFFFFFF || i < -0xfffffff {
		panic("s2u out of range");
	} else if i >= 0 {
		return uint32(i);
	} else {
		return (0x10000000|uint32(-i));
	}
}

// uint29 -> signed int
func u2s(u uint32) int32 {
	if u > 0x1FFFFFFF {
		panic("u2s out of range");
	}

	if (u&0x10000000) == 0 {
		return int32(u);
	} else {
		return -int32(u&0xfffffff);
	}
}

func encodeInt(w io.Writer, value int64) (int, error) {
	if value > 0xFFFFFFF || value < -0xFFFFFFF {
        return encodeFloat(w, float64(value));
	}

	if _, err := writeAmfType(w, amf_integer); err != nil {
		return 0, err;
	}

	u := s2u(int32(value));
	n, err := encodeU29(w, u);
	return n + 1, err;
}

func encodeUint(w io.Writer, value uint64) (int, error) {
	if value > 0xFFFFFFF {
        return encodeFloat(w, float64(value));
    }

	if _, err := writeAmfType(w, amf_integer); err != nil {
		return 0, err;
	}
	n, err := encodeU29(w, uint32(value));
	return n + 1, err;
}

// integer and uinteger
func decodeInteger(r io.Reader) (int64, error) {
	value, err := decodeU29(r);
	if err != nil {
		return 0, nil;
	}
	return int64(u2s(value)), nil;
}

func encodeFloat(w io.Writer, value float64) (int, error) {
	if _, err := writeAmfType(w, amf_double); err != nil {
		return 0, err;
	}
	return 9, binary.Write(w, binary.BigEndian, value);
}

// float
func decodeFloat(r io.Reader) (float64, error) {
	var value float64 = 0;
	err := binary.Read(r, binary.BigEndian, &value);
	return value, err;
}

// array and byte array
func encodeArray(w io.Writer, value reflect.Value, ref *ReferenceLog) (int, error) {
	in := value.Interface();

	switch in.(type) {
		case []byte:
			return encodeByteArray(w, in.([]byte), ref);
		default:
			break;
	}

	if _, err := writeAmfType(w, amf_array); err != nil {
		return 0, err;
	}

	l := value.Len();

	el := uint32((l<<1)|1);

	if el > 0x1FFFFFFF {
		return 0, ErrLogLength;
	}
	nl, err := encodeU29(w, el);
	if err != nil {
		return 0, err;
	}

	if _, err := w.Write([]byte{0x01}); err != nil {
		return 0, err;
	}


	tl := nl + 2;

	for i := 0; i < l; i++ {
		nc, err := encodeWithRef(w, value.Index(i), ref);
		if err != nil {
			return 0, err;
		}
		tl += nc;
	}
	return tl, err;
}

func decodeArray(r io.Reader, ref *ReferenceLog) ([]interface{}, error) {
	l, err := decodeU29(r);
	if err != nil {
		return nil, err;
	}

	// isRef := ((l & 1) == 0);
	l = l >> 1;

	// name 
	bs := make([]byte,1)
	if	_, err = r.Read(bs); err != nil {
		return nil, err;
	}

	ret := make([]interface{}, l);
	for i := uint32(0); i < l; i++ {
		ret[i], err = decodeWithRef(r, ref);
		if err != nil {
			return nil, err;
		}
	}
	return ret, nil;
}

func decodeArrayTo(r io.Reader, value reflect.Value, ref *ReferenceLog) error {
	l, err := decodeU29(r);
	if err != nil {
		return err;
	}

	// isRef := ((l & 1) == 0);
	l = l >> 1;

	// name 
	bs := make([]byte,1)
	if	_, err = r.Read(bs); err != nil {
		return err;
	}


	if value.Kind() == reflect.Array || value.Kind() == reflect.Slice  {
		for i := 0; i < int(l); i++ {
			if i < value.Len() {
				err = decodeToWithRef(r, value.Index(i), ref);
				if err != nil {
					return err;
				}
			}
		}
	} else {
		for i := 0; i < int(l); i++ {
			if i < value.NumField() {
				err = decodeToWithRef(r, value.Field(i), ref);
				if err != nil {
					return err;
				}
			}
		}
	}
	return nil;
}


func encodeArrayWithStruct(w io.Writer, value reflect.Value, ref *ReferenceLog) (int, error) {
	if _, err := w.Write([]byte{amf_array}); err != nil {
		return 0, err;
	}

	l := value.NumField();
	el := uint32((l<<1)|1);

	if el > 0x1FFFFFFF {
		return 0, ErrLogLength;
	}
	nl, err := encodeU29(w, el);
	if err != nil {
		return 0, err;
	}

	if _, err := w.Write([]byte{0x01}); err != nil {
		return 0, err;
	}


	tl := nl + 2;

	for i := 0; i < l; i++ {
		nc, err := encodeWithRef(w, value.Field(i), ref);
		if err != nil {
			return 0, err;
		}
		tl += nc;
	}
	return tl, err;
}


// string and byte array
func encodeByteArray(w io.Writer, value []byte, ref *ReferenceLog) (int, error) {
	if _, err := writeAmfType(w, amf_byte_array); err != nil {
		return 0, err;
	}

	isRef := false;

	l := uint32(len(value));

/*
	// no reference
	for i := 0; i < len(ref.Bytes); i++ {
		if ref.Bytes[i] == value {
			l = uint32(i);
			isRef = true;
			break;
		}
	}
*/

	if (isRef) {
		l = l << 1;
	} else {
		l = (l<<1)|1;
	}

	if l > 0x1FFFFFFF {
		return 0, ErrLogLength;
	}

	nl, err := encodeU29(w, l);
	if err != nil {
		return 0, err;
	}

	ns := 0;
	if !isRef {
		ns, err = w.Write(value);
		if err != nil {
			return 0, err;
		}
//		ref.Bytes = append(ref.Bytes, value);
	}
	return ns + nl + 1, nil;
}

func decodeByteArray(r io.Reader, ref * ReferenceLog) ([]byte, error) {
	l, err := decodeU29(r);
	if err != nil {
		return nil, err;
	}

	isRef := ((l & 1) == 0);
	l = l >> 1;

	if isRef {
		if len(ref.Bytes) > 0 {
			return ref.Bytes[l], nil;
		} else {
			return nil, ErrReference;
		}
	} else {
		bs := make([]byte, l);
		_, err := io.ReadFull(r, bs);
		if err != nil {
			return nil, err;
		}
		ref.Bytes = append(ref.Bytes, bs);
		return bs, nil;
	}
}

func encodeString(w io.Writer, value string, ref *ReferenceLog) (int, error) {
	if _, err := writeAmfType(w, amf_string); err != nil {
		return 0, err;
	}

	isRef := false;

	l := uint32(len(value));

	for i := 0; i < len(ref.Strings); i++ {
		if ref.Strings[i] == value {
			l = uint32(i);
			isRef = true;
			break;
		}
	}

	if (isRef) {
		l = l << 1;
	} else {
		l = (l<<1)|1;
	}

	if l > 0x1FFFFFFF {
		return 0, ErrLogLength;
	}

	nl, err := encodeU29(w, l);
	if err != nil {
		return 0, err;
	}

	ns := 0;
	if !isRef {
		ns, err = w.Write([]byte(value));
		if err != nil {
			return 0, err;
		}
		ref.Strings = append(ref.Strings, value);
	}
	return ns + nl + 1, nil;
}

func decodeString(r io.Reader, ref * ReferenceLog) (string, error) {
	l, err := decodeU29(r);
	if err != nil {
		return "", err;
	}

	isRef := ((l & 1) == 0);
	l = l >> 1;

	if isRef {
		if len(ref.Strings) > 0 {
			return ref.Strings[l], nil;
		} else {
			return "", ErrReference;
		}
	} else {
		bs := make([]byte, l);
		_, err := io.ReadFull(r, bs);
		if err != nil {
			return "", err;
		}
		ref.Strings = append(ref.Strings, string(bs));
		return string(bs), nil;
	}
}


const (
    amf_undefine   = 0x00;
    amf_null       = 0x01;
    amf_false      = 0x02;
    amf_true       = 0x03;
    amf_integer    = 0x04;
    amf_double     = 0x05;
    amf_string     = 0x06;
    amf_xml_doc    = 0x07;
    amf_date       = 0x08;
    amf_array      = 0x09;
    amf_object     = 0x0A;
    amf_xml        = 0x0B;
    amf_byte_array = 0x0C;
);

func encodeU29(w io.Writer, value uint32) (int, error) {
	if value <= 0x7F {
		return w.Write([]byte{
				byte(value & 0x7f),
				});
    } else if value <= 0x00003FFF {
		return w.Write([]byte{
				byte(value>>7)        |0x80,
				byte(value&0x7f),
				});
	} else if value <= 0x001FFFFF {
		return w.Write([]byte{
				byte(value>>14)       |0x80,
				byte((value>>7)&0x7F) |0x80,
				byte(value&0x7F),
				});
	} else if value <= 0x1FFFFFFF {
		return w.Write([]byte{
				byte(value>>22)       |0x80,
				byte((value>>15)&0x7F)|0x80,
				byte((value>>8)&0x7F) |0x80,
				byte(value & 0xFF),
				});

	} else {
		return 0, ErrU29OutOfRange;
	}
}

func decodeU29(r io.Reader) (uint32, error) {
	var value uint32 = 0;
	bs := make([]byte, 1);

	for i := 0; i < 4; i++ {
		_, err := r.Read(bs);
		if err != nil {
			return 0, err;
		}

		c := bs[0];
		if i != 3 {
			value |= (uint32)(c&0x7F);
			if (c&0x80) != 0 {
				if i != 2 {
					value <<= 7;
				} else {
					value <<= 8;
				}
			} else {
				break;
			}
		} else {
			value |= uint32(c);
			break;
		}
	}
	return value, nil;
}

func EncodeAmf(item interface{})([]byte, error){
	var buf bytes.Buffer
	if _, err := Encode(&buf, item); err!=nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
