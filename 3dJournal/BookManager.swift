//
//  BookManager.swift
//  3dJournal
//
//  Created by Trevor Clute on 4/4/25.
//

import CoreData
import Foundation
import SceneKit

let ANIMATION_TIME = 0.7

class BookManager {
    let scene: SCNScene?
    let textView: UITextView?
    let context: NSManagedObjectContext
    let nullNode: SCNNode = {
        let n = SCNNode()
        n.position.x = 0
        n.position.y = 0
        n.position.z = 0
        return n
    }()
    
    var books: [BookNode] = []

    var bookDictinary: [UUID:Int] {
        var bd : [UUID:Int] = [:]
        for (i,book) in books.enumerated() {
            bd.updateValue(i, forKey: book.id)
        }
        return bd
    }
    
    init(
        scene: SCNScene, textView: UITextView,
        context: NSManagedObjectContext
    ) {
        self.context = context
        self.textView = textView
        self.scene = scene
        getBooks()
    }
    static var fontSize: CGFloat = 40
    static var activeBook: BookNode?

    func getBooks() {
        let books = scene?.rootNode.childNodes(passingTest: { child, ptr in
            if child.name == "book" {
                return true
            }
            return false
        })
        self.books = books as! [BookNode]
    }
    

    enum DuplicateBookError: Error {
        case sameLocation
    }
    func createBook(position: SCNVector3, color: UIColor, title: String) throws
        -> BookNode
    {
        // Create parent node for the entire book
        let bookNode = BookNode(position: position, color: color)
        BookManager.activeBook = bookNode

        for book in books {
            if book.position.x == position.x && book.position.y == position.y
                && book.position.z == position.z
            {
                throw DuplicateBookError.sameLocation
            }
        }

        let textNode = TitleNode(
            bookNode: bookNode, scene: self.scene!, title: title)
        bookNode.titleNode = textNode

        return bookNode
    }

    func handleClick(bookNode: BookNode, cameraNode: SCNNode) {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        if bookNode.status == .open {
            textView?.resignFirstResponder()
            bookNode.close(cameraNode: cameraNode)
            BookManager.activeBook = nil
            textView?.text = ""
        } else {
            bookNode.open(cameraNode: cameraNode)
            BookManager.activeBook = bookNode
        }

        SCNTransaction.commit()
    }
    func intToColor(_ num: Int) -> UIColor {
        switch num {
        case 1:
            return .systemRed
        case 2:
            return .systemOrange
        case 3:
            return .systemYellow
        case 4:
            return .systemGreen
        case 5:
            return .systemBlue
        case 6:
            return .systemIndigo
        case 7:
            return .systemPink
        case 8:
            return .systemCyan
        default:
            return .systemGray
        }
    }

    func colorToInt(_ color: UIColor) -> Int {
        switch color {
        case .systemRed:
            return 1
        case .systemOrange:
            return 2
        case .systemYellow:
            return 3
        case .systemGreen:
            return 4
        case .systemBlue:
            return 5
        case .systemIndigo:
            return 6
        case .systemPink:
            return 7
        case .systemCyan:
            return 8
        default:
            return 0
        }
    }

    func addNewBookToDataBase(bookNode: BookNode) {
        DispatchQueue.global(qos: .userInitiated).async {
            let book = NSEntityDescription.insertNewObject(
                forEntityName: "Book", into: self.context)
            let colorInt = self.colorToInt(bookNode.color)
            book.setValue(colorInt, forKey: "color")
            book.setValue(bookNode.id, forKey: "id")
            book.setValue(bookNode.text.string, forKey: "text")
            book.setValue(
                bookNode.titleNode?.attributedString.string, forKey: "title")
            book.setValue(bookNode.position.x, forKey: "x")
            book.setValue(bookNode.position.y, forKey: "y")
            book.setValue(bookNode.position.z, forKey: "z")
            do {
                try self.context.save()
            }
            catch {
                print("error\(error)")
            }
        }
    }

    func updateBookInDataBase(id: UUID, text: String) {
        let fetchReq = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetchReq.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let results = try context.fetch(fetchReq)
            if let book = results.first {
                book.setValue(text, forKey: "text")
                try context.save()
            }
        } catch {
            print("error \(error)")
        }
    }
    
    func removeBookFromDataBase(id:UUID) {
        let fetchReq = NSFetchRequest<NSManagedObject>(entityName: "Book")
        fetchReq.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let results = try context.fetch(fetchReq)
            if let book = results.first {
                context.delete(book)
                try context.save()
            }
        } catch {
            print("error \(error)")
        }
    }
    
    func loadBooksFromDataBase() {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Book")
        let results = try? context.fetch(fetchRequest)
        DispatchQueue.global(qos: .background).async {
            for result in results ?? [] {
                let color = self.intToColor(
                    result.value(forKey: "color") as? Int ?? 0)
                let id = result.value(forKey: "id") as! UUID
                let text = result.value(forKey: "text") as! String
                let title = result.value(forKey: "title") as! String
                let x = result.value(forKey: "x") as! Double
                let y = result.value(forKey: "y") as! Double
                let z = result.value(forKey: "z") as! Double
                do {
                    let bookNode = try self.createBook(
                        position: SCNVector3(
                            x: Float(x), y: Float(y), z: Float(z)),
                        color: color, title: title)
                    bookNode.setText(NSAttributedString(string: text))
                    bookNode.id = id
                    self.books.append(bookNode)
                    DispatchQueue.main.async {
                        self.scene?.rootNode.addChildNode(bookNode)
                        self.scene?.rootNode.addChildNode(bookNode.titleNode!)
                    }
                } catch {}
            }
        }
    }
    
    func removeBook(book:BookNode){
        removeBookFromDataBase(id: book.id)
        if let title = book.titleNode {
            title.removeFromParentNode()
        }
        if let index = bookDictinary[book.id] {
            books.remove(at: index)
        }
//        getBooks()
        book.removeFromParentNode()
    }

    func beginWrite(bookNode: BookNode, cameraNode: SCNNode) {
        if bookNode.status == .closed {
            bookNode.open(cameraNode: cameraNode)
        }
        textView?.text = bookNode.text.string
        self.textView?.becomeFirstResponder()
        BookManager.activeBook = bookNode
    }

    func write(text: NSAttributedString) {
        if let active = BookManager.activeBook {
            active.setText(text)
            updateBookInDataBase(id: active.id, text: text.string)
        }
    }
}
