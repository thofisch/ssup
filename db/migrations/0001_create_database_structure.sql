CREATE TABLE [Reservation] (
    [Id] INT NOT NULL IDENTITY, 
    [ReservationCode] VARCHAR(10) NOT NULL,
    [CurrencyCode] CHAR(3) NOT NULL,
    [LastProcessed] DATETIME NOT NULL,

    CONSTRAINT [PK_Reservation_Id] PRIMARY KEY ([Id]),
)

CREATE TABLE [Invoice] (
    [Id] INT NOT NULL IDENTITY, 
    [ReservationId] INT NOT NULL,
    [Number] VARCHAR(20)  NULL,
    [DocumentType] VARCHAR(10)  NULL,
    [MultiInvoiced] BIT NOT NULL DEFAULT 0,
    [TotalAmount] NUMERIC(12,2) NULL,
    [ToPay] NUMERIC(12,2) NULL,
    [IssueDate] DATETIME NULL,
    [DueDate] DATETIME NULL,
    [CreatedDate] DATETIME NULL,

    CONSTRAINT [PK_Invoice_Id] PRIMARY KEY ([Id])
)

ALTER TABLE [Invoice]
    ADD CONSTRAINT [FK_Invoice_ReservationId]
    FOREIGN KEY ([ReservationId])
    REFERENCES [Reservation] ([Id])

CREATE NONCLUSTERED INDEX [IX_Reservation_ReservationCode] 
    ON [Reservation] ([ReservationCode]) 
    WITH (ONLINE = ON, FILLFACTOR = 90)

CREATE UNIQUE INDEX [IX_Invoice_ReservationCode_Unique] 
    ON [Reservation] ([ReservationCode]) 
    WITH (FILLFACTOR = 90)

CREATE NONCLUSTERED INDEX [IX_Invoice_ReservationId] 
    ON [Invoice] ([ReservationId]) 
    INCLUDE ([Number], [DocumentType], [MultiInvoiced], [TotalAmount], [ToPay], [IssueDate], [DueDate]) 
    WITH (ONLINE = ON, FILLFACTOR = 90)

CREATE UNIQUE INDEX [IX_Invoice_ReservationId_Number_DocumentType_Unique] 
    ON [Invoice] ([ReservationId], [Number], [DocumentType]) 
    WITH (FILLFACTOR = 90)
