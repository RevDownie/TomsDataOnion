package main

import (
  "bytes"
  "encoding/ascii85"
  "encoding/hex"
  "errors"
  "io/ioutil"
)

// Tom's Data Onion - Layer 3
// https://www.tomdalling.com/toms-data-onion/
//
// Solve the next layer of the puzzle which is Ascii85 conversion followed by
// figuring out the XOR encryption key
//
// To RUN: go run layer3.go
//
func main() {
  //Read the payload
  encoded_data, read_err := ioutil.ReadFile("layer3_payload.txt")
  if read_err != nil {
    panic(read_err)
  }
  encoded_data_slice := encoded_data[2 : len(encoded_data)-2] //Slice of the delimeters

  //Decode the payload from Ascii85
  decoded_buffer := make([]byte, 500*1024)
  ndst, _, decode_err := ascii85.Decode(decoded_buffer, encoded_data_slice, true)
  if decode_err != nil {
    panic(decode_err)
  }
  encrypted_data := decoded_buffer[:ndst]

  //Crack the 'encryption'
  //Because the previous instructions follow a similar format we can make a good guess at what some of the decrypted data will be and use that to figure out the key
  //We know the opening line will be '==[ Layer 4/6: ' but that isn't long enough to decrypt our 32 byte key. However we also know the file will contain
  //'==[ Payload ]===============================================' which is long enough but we don't know where in the file it will be.
  //We can partially decrypt with a partial key and then look for the payload line to get the rest
  const known_decoded = "==[ Layer 4/6: "
  var key [32]byte
  for i := 0; i < len(known_decoded); i++ {
    key[i] = known_decoded[i] ^ encrypted_data[i]
  }

  //First decryption pass to get more known data
  decrypted_data := make([]byte, ndst)
  dec_err := decrypt(decrypted_data, encrypted_data, key)
  if dec_err != nil {
    panic(dec_err)
  }

  //Search for start of payload line based on output from previous run
  //3d 3dc5 8549 54
  known_partial, hex_err := hex.DecodeString("3d3dc5854954ef")
  if hex_err != nil {
    panic(hex_err)
  }
  found_idx := bytes.Index(decrypted_data, known_partial)
  if found_idx < 0 {
    panic("Cannot find payload string")
  }

  //Build the full key - starting at the offset
  const known_decoded2 = "==[ Payload ]==================="
  for i := 0; i < 32; i++ {
    key[(found_idx+i)%32] = known_decoded2[i] ^ encrypted_data[found_idx+i]
  }

  //Second full decryption pass
  dec_err2 := decrypt(decrypted_data, encrypted_data, key)
  if dec_err2 != nil {
    panic(dec_err2)
  }

  //Output the next layer's instructions
  write_err := ioutil.WriteFile("layer4_instructions.txt", decrypted_data, 0644)
  if write_err != nil {
    panic(write_err)
  }
}

// Simple xor with a wrapping 32 byte key to decrypt the data
//
func decrypt(decrypted_output []byte, encrypted_data []byte, key [32]byte) error {
  if len(decrypted_output) < len(encrypted_data) {
    return errors.New("Decryption buffer not large enough")
  }

  for i := 0; i < len(encrypted_data); i++ {
    decrypted_output[i] = encrypted_data[i] ^ key[i%32]
  }

  return nil
}
