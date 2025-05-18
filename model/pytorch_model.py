import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import numpy as np
import csv
# Define the quantizable CNN architecture
class QuantizedCNN(nn.Module):
    def __init__(self):
        super(QuantizedCNN, self).__init__()
        # Quantization stubs
        self.quant = torch.quantization.QuantStub()
        self.dequant = torch.quantization.DeQuantStub()
        # First convolutional layer
        self.conv1 = nn.Conv2d(1, 2, kernel_size=5)
        self.relu1 = nn.ReLU()
        self.pool1 = nn.MaxPool2d(2, 2)
        # Second convolutional layer
        self.conv2 = nn.Conv2d(2, 4, kernel_size=3)
        self.relu2 = nn.ReLU()
        self.pool2 = nn.MaxPool2d(2, 2)
        # Fully connected layer
        self.fc1 = nn.Linear(100, 10)

    def forward(self, x):
        x = self.quant(x)
        x = self.conv1(x)
        x = self.relu1(x)
        x = self.pool1(x)
        x = self.conv2(x)
        x = self.relu2(x)
        x = self.pool2(x)
        x = x.reshape(-1, 100)
        x = self.fc1(x)
        x = self.dequant(x)
        return x

# Data preprocessing and augmentation
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,))  # Normalize to mean=0.1307, std=0.3081
])

# Load datasets
train_dataset = datasets.MNIST(
    root='./data',
    train=True,
    download=True,
    transform=transform
)
test_dataset = datasets.MNIST(
    root='./data',
    train=False,
    download=True,
    transform=transform
)

# Data loaders
batch_size = 64
train_loader = torch.utils.data.DataLoader(
    dataset=train_dataset,
    batch_size=batch_size,
    shuffle=True
)
test_loader = torch.utils.data.DataLoader(
    dataset=test_dataset,
    batch_size=batch_size,
    shuffle=False
)

# Initialize the model
model = QuantizedCNN()

# Specify quantization configuration
model.qconfig = torch.quantization.get_default_qat_qconfig('qnnpack')

# Fuse modules where appropriate
torch.quantization.fuse_modules(
    model,
    [['conv1', 'relu1'],
     ['conv2', 'relu2']],
    inplace=True
)

# Prepare for quantization-aware training
model_prepared = torch.quantization.prepare_qat(model)

# Move model to training mode
model_prepared.train()

# Loss function and optimizer
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model_prepared.parameters(), lr=0.001)

# Training loop
num_epochs = 1#5
for epoch in range(num_epochs):
    model_prepared.train()
    running_loss = 0.0
    for batch_idx, (inputs, targets) in enumerate(train_loader):
        optimizer.zero_grad()           # Zero the parameter gradients
        outputs = model_prepared(inputs)         # Forward pass
        loss = criterion(outputs, targets)  # Compute loss
        loss.backward()                 # Backward pass
        optimizer.step()                # Optimize weights
        running_loss += loss.item()
        if batch_idx % 100 == 99:
            print(f'Epoch [{epoch+1}/{num_epochs}], '
                  f'Step [{batch_idx+1}/{len(train_loader)}], '
                  f'Loss: {running_loss / 100:.4f}')
            running_loss = 0.0

# Convert to quantized model
torch.backends.quantized.engine = 'qnnpack'  # or 'qnnpack'
model_quantized = torch.quantization.convert(model_prepared.eval(), inplace=False)

# Evaluation on test data
model_quantized.eval()
correct = 0
total = 0
with torch.no_grad():
    for inputs, targets in test_loader:
        outputs = model_quantized(inputs)
        _, predicted = torch.max(outputs.data, 1)
        total += targets.size(0)
        correct += (predicted == targets).sum().item()
print(f'Test Accuracy: {100 * correct / total:.2f}%')
