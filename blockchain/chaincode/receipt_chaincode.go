// ScrapChain receipt chaincode — Hyperledger Fabric 2.5 (contract API).
//
// Deploy:
//   peer lifecycle chaincode package receipt.tar.gz --path . --lang golang --label receipt_1
//   peer lifecycle chaincode install receipt.tar.gz
//   ... approve + commit on scrapchain-channel
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"strconv"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ReceiptContract struct {
	contractapi.Contract
}

type DigitalReceipt struct {
	ReceiptID   string  `json:"receipt_id"`
	ItemType    string  `json:"item_type"`
	Material    string  `json:"material"`
	WeightKg    float64 `json:"weight_kg"`
	PricePerKg  float64 `json:"price_per_kg"`
	TotalAmount float64 `json:"total_amount"`
	CollectorID string  `json:"collector_id"`
	RecyclerID  string  `json:"recycler_id"`
	Timestamp   string  `json:"timestamp"`
	TxID        string  `json:"tx_id"`
}

// MintReceipt records an e-waste handover on the ledger.
// The receipt ID is the SHA-256 of the canonical transaction payload.
func (c *ReceiptContract) MintReceipt(
	ctx contractapi.TransactionContextInterface,
	itemType, material, weightStr, priceStr, collectorID, recyclerID string,
) (string, error) {
	weight, err := strconv.ParseFloat(weightStr, 64)
	if err != nil || weight <= 0 {
		return "", fmt.Errorf("invalid weight: %s", weightStr)
	}
	price, err := strconv.ParseFloat(priceStr, 64)
	if err != nil || price <= 0 {
		return "", fmt.Errorf("invalid price: %s", priceStr)
	}

	ts, _ := ctx.GetStub().GetTxTimestamp()
	when := time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)

	payload := fmt.Sprintf("%s|%s|%f|%f|%s|%s|%s",
		itemType, material, weight, price, collectorID, recyclerID, when)
	sum := sha256.Sum256([]byte(payload))
	receiptID := hex.EncodeToString(sum[:])

	receipt := DigitalReceipt{
		ReceiptID:   receiptID,
		ItemType:    itemType,
		Material:    material,
		WeightKg:    weight,
		PricePerKg:  price,
		TotalAmount: weight * price,
		CollectorID: collectorID,
		RecyclerID:  recyclerID,
		Timestamp:   when,
		TxID:        ctx.GetStub().GetTxID(),
	}

	receiptJSON, err := json.Marshal(receipt)
	if err != nil {
		return "", err
	}
	if err := ctx.GetStub().PutState(receiptID, receiptJSON); err != nil {
		return "", err
	}

	// Composite key for per-collector history queries
	collectorKey, err := ctx.GetStub().CreateCompositeKey(
		"collector~receipt", []string{collectorID, receiptID})
	if err != nil {
		return "", err
	}
	if err := ctx.GetStub().PutState(collectorKey, []byte{0}); err != nil {
		return "", err
	}

	return receiptID, nil
}

// VerifyReceipt returns the receipt stored under receiptID, or an error.
func (c *ReceiptContract) VerifyReceipt(
	ctx contractapi.TransactionContextInterface, receiptID string,
) (*DigitalReceipt, error) {
	data, err := ctx.GetStub().GetState(receiptID)
	if err != nil {
		return nil, err
	}
	if data == nil {
		return nil, fmt.Errorf("receipt %s not found", receiptID)
	}
	var receipt DigitalReceipt
	if err := json.Unmarshal(data, &receipt); err != nil {
		return nil, err
	}
	return &receipt, nil
}

// GetReceiptHistory returns all receipts minted by a collector.
func (c *ReceiptContract) GetReceiptHistory(
	ctx contractapi.TransactionContextInterface, collectorID string,
) ([]*DigitalReceipt, error) {
	iter, err := ctx.GetStub().GetStateByPartialCompositeKey(
		"collector~receipt", []string{collectorID})
	if err != nil {
		return nil, err
	}
	defer iter.Close()

	receipts := []*DigitalReceipt{}
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, err
		}
		_, parts, err := ctx.GetStub().SplitCompositeKey(kv.Key)
		if err != nil || len(parts) != 2 {
			continue
		}
		receipt, err := c.VerifyReceipt(ctx, parts[1])
		if err == nil {
			receipts = append(receipts, receipt)
		}
	}
	return receipts, nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&ReceiptContract{})
	if err != nil {
		log.Panicf("error creating receipt chaincode: %v", err)
	}
	if err := chaincode.Start(); err != nil {
		log.Panicf("error starting receipt chaincode: %v", err)
	}
}
